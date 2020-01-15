#!/bin/bash

###
# Utils

function prep_dir() {
  mkdir -p $1
}

get_ssm_param() {
  local param=$(aws $PROFILE_ARG ssm get-parameters --region "$AWS_REGION" --name "$1" --with-decryption \
    --query Parameters[0].Value | sed -e 's/^"//' -e 's/"$//')
  echo "$param"
}

# Creates an aws profile on CodeBuild instance
# credential_source will behave differently on local laptop
prep_aws_profile() {
  local name='codebuild'
  aws configure --profile $name set role_arn $1
  aws configure --profile $name set credential_source EcsContainer
  echo "$name"
}

###
# Lambda functions

function version_by_alias() {
  local f_name=$1
  local f_alias=$2

  local v=$(aws $PROFILE_ARG lambda get-alias --function-name ${f_name} --name ${f_alias} --query '[to_number(FunctionVersion)]' --output text)

  # If no alias defined, create one
  if [[ -z "${v}" || "None" == "${v}" ]]; then
    v="1"
    aws $PROFILE_ARG lambda create-alias --function-name ${f_name} --name ${f_alias} --function-version "$v"
  fi

  echo "$v"
}

# Update lambda, publish and return version
function update_lambda() {
  local f_name=$1
  local zipFile=$2

  local response=$(aws $PROFILE_ARG lambda update-function-code --function-name ${f_name} --zip-file fileb://${zipFile} --publish | jq --raw-output '.Version')

  local status=$?
  if [[ ${status} -ne 0 ]]; then
    echo "Failed to update and publish new version for lambda ${f_name}: $status"
    exit ${status}
  fi

  echo "$response"
}

###
# CodeDeploy functions

# TODO: There is an issue with CodeDeploy and Lambda Alias version $LATEST
# TODO: appspec.yml does not like CurrentVersion < 0.
function appspec() {
  m4 -D NAME="$1" \
    -D ALIAS="$2" \
    -D CURRENT_VERSION="$3" \
    -D TARGET_VERSION="$4" \
    "appspec.yml.m4" > "${5}/appspec.yml"
}


function create_deployment() {
  local app_name=$1
  local dep_grp_name=$2
  local bucket=$3
  local appspec=$4

  local response=$(aws $PROFILE_ARG deploy create-deployment --region "$AWS_REGION" --application-name "$app_name" --deployment-group-name "$dep_grp_name" --s3-location bucket=$bucket,bundleType=YAML,key=$app_name/$appspec --query 'deploymentId' --output text)

  local status=$?
  if [[ ${status} -ne 0 ]]; then
    echo "Failed to create deployment for lambda ${app_name}: $status"
    exit ${status}
  fi

  echo "${response}"
}

function deployment_status() {
  local id=$1
  local ret=1
  local ntimes=10
  local nsleep=10
  local success=""

  for i in $(seq 1 ${ntimes}); do
    local result=$(aws $PROFILE_ARG deploy get-deployment --region "$AWS_REGION" --deployment-id "$id")

    local status=$?
    if [[ ${status} -ne 0 ]]; then
      echo "Failed to get deployment status ${id}: ${status}"
      ret=${status}
    fi

    success=$(echo "$result" | jq --raw-output '.deploymentInfo.status')

    if [[ "$success" == "Succeeded" ]]; then
      ret=0
      break
    elif [[ "$success" == "Failed" ]]; then
      local error=$(echo "$result" | jq --raw-output '.deploymentInfo.errorInformation | (.code + " : " + .message)')
      echo "Failed to deploy lambda_ ${error}"
      exit 1
      break
    fi

    echo "Will retry ${i}/${ntimes}"
    echo "Result: ${result}"
    sleep ${nsleep}
  done

  if [[ ${ret} -ne 0 ]]; then
    echo "Failed to deploy lambda_ ${success}"
    exit ${ret}
  fi

  echo "${success}"
}

function upload_revision() {
  local app_name=$1
  local source=$2
  local bucket=$3
  local build_tag=$4

  aws $PROFILE_ARG s3 cp "$source" "s3://${bucket}/${app_name}/${build_tag}"

  local status=$?
  if [[ ${status} -ne 0 ]]; then
    echo "Failed to upload revision to s3 ${bucket}/${CODE_DEPLOY_APP_NAME}/${build_tag}: $status"
    exit ${status}
  fi
}


###
# Validate & prepare

if [[ -z "$AWS_REGION" ]]; then
  echo "AWS_REGION is missing."
  exit 1
fi

if [[ -z "$FUNCTION_NAME" ]]; then
  echo "FUNCTION_NAME is missing."
  exit 1
fi

if [[ -z "$FUNCTION_ALIAS" ]]; then
  echo "FUNCTION_ALIAS is missing."
  exit 1
fi

if [[ -z "$APPZIP_DIR" ]]; then
  echo "APPZIP_DIR is missing."
  exit 1
fi

if [[ -z "$BUILD_DIR" ]]; then
  echo "BUILD_DIR is missing."
  exit 1
fi

if [[ -z "$BUILD_ARTIFACT" ]]; then
  echo "BUILD_ARTIFACT is missing."
  exit 1
fi

if [[ -z "$BUILD_TAG" ]]; then
  echo "BUILD_TAG is missing."
  exit 1
fi

if [[ -z "$CODE_DEPLOY_APP_NAME" ]]; then
  echo "CODE_DEPLOY_APP_NAME is missing."
  exit 1
fi

if [[ -z "$CODE_DEPLOY_GROUP" ]]; then
  echo "CODE_DEPLOY_GROUP is missing."
  exit 1
fi

# ASSUME_ROLE is set to apply cross-acount changes
if [[ -z "$ASSUME_ROLE" ]]; then
  PROFILE_ARG=""

  # Allowing local builds with PROFILE environment variable
  # for profile managed by session tools / local assume role setup
  if [[ $PROFILE ]]; then
    PROFILE_ARG="--profile $PROFILE"
  fi
else
  echo "Creating profile for $ASSUME_ROLE"
  PROFILE_NAME=$(prep_aws_profile $ASSUME_ROLE)
  PROFILE_ARG="--profile $PROFILE_NAME"
  aws configure list
fi

if [[ -z "$CODE_DEPLOY_REVISIONS" ]]; then
  CODE_DEPLOY_REVISIONS=$(get_ssm_param '/ci/codedeploy/bucket_id')
fi


###
# Run

prep_dir "$BUILD_DIR"

echo "Updating lambda function"
target_version=$(update_lambda "$FUNCTION_NAME" "$APPZIP_DIR/$APPZIP_NAME")
# echo "Latest version: ${target_version}"

echo "Getting lambda alias version"
active_version=$(version_by_alias "$FUNCTION_NAME" "$FUNCTION_ALIAS")

# echo "Latest alias version: ${active_version}"

echo "Writing appspec.yml for CodeDeploy"
appspec "$FUNCTION_NAME" "$FUNCTION_ALIAS" "$active_version" "$target_version" "$BUILD_DIR"

if [[ $? -ne 0 ]]; then
  echo "Failed writing appspec.yml"
  exit 1
fi

echo "Upload revision to CodeDeploy"
upload_revision "$CODE_DEPLOY_APP_NAME" "${BUILD_DIR}/appspec.yml" "$CODE_DEPLOY_REVISIONS" "$BUILD_TAG"

if [[ $? -ne 0 ]]; then
  echo "Failed to upload revision"
  exit 1
fi

echo "Trigger deploy on CodeDeploy"
DEPLOYMENT_ID=$(create_deployment "$CODE_DEPLOY_APP_NAME" "$CODE_DEPLOY_GROUP" "$CODE_DEPLOY_REVISIONS" "$BUILD_TAG")

if [[ $? -ne 0 ]] || [[ -z ${DEPLOYMENT_ID} ]]; then
  echo "Failed to create deployment ${DEPLOYMENT_ID}"
  exit 1
fi

msg=$(deployment_status "$DEPLOYMENT_ID")

if [[ $? -ne 0 ]]; then
  echo "Failed when checking deployent status ${msg}"
  exit 1
fi

echo "Done"
exit 0

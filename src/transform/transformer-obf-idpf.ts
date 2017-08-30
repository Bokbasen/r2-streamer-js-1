import * as crypto from "crypto";

import { Publication } from "@models/publication";
import { Link } from "@models/publication-link";
import { bufferToStream, streamToBufferPromise } from "@utils/stream/BufferUtils";
import { IStreamAndLength } from "@utils/zip/zip";

import { ITransformer } from "./transformer";

export class TransformerObfIDPF implements ITransformer {
    public supports(_publication: Publication, link: Link): boolean {
        return link.Properties.Encrypted.Algorithm === "http://www.idpf.org/2008/embedding";
    }

    public async transformStream(
        publication: Publication, link: Link,
        stream: NodeJS.ReadableStream, _totalByteLength: number,
        _partialByteBegin: number, _partialByteEnd: number): Promise<IStreamAndLength> {

        const data = await streamToBufferPromise(stream);
        const buff = await this.transformBuffer(publication, link, data);

        const sal: IStreamAndLength = {
            length: buff.length,
            stream: bufferToStream(buff),
        };
        return Promise.resolve(sal);
    }

    public async transformBuffer(publication: Publication, _link: Link, data: Buffer): Promise<Buffer> {

        let pubID = publication.Metadata.Identifier;
        pubID = pubID.replace(/\s/g, "");

        const checkSum = crypto.createHash("sha1");
        checkSum.update(pubID);
        // const hash = checkSum.digest("hex");
        // console.log(hash);
        const key = checkSum.digest();

        const prefixLength = 1040;
        const zipDataPrefix = data.slice(0, prefixLength);

        for (let i = 0; i < prefixLength; i++) {
            /* tslint:disable:no-bitwise */
            zipDataPrefix[i] = zipDataPrefix[i] ^ (key[i % key.length]);
        }

        const zipDataRemainder = data.slice(prefixLength);
        return Promise.resolve(Buffer.concat([zipDataPrefix, zipDataRemainder]));
    }
}

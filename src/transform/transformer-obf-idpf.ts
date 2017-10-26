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
        stream: IStreamAndLength,
        _isPartialByteRangeRequest: boolean,
        _partialByteBegin: number, _partialByteEnd: number): Promise<IStreamAndLength> {

        let data: Buffer;
        try {
            data = await streamToBufferPromise(stream.stream);
        } catch (err) {
            return Promise.reject(err);
        }

        let buff: Buffer;
        try {
            buff = await this.transformBuffer(publication, link, data);
        } catch (err) {
            return Promise.reject(err);
        }

        const sal: IStreamAndLength = {
            length: buff.length,
            reset: async () => {
                return Promise.resolve(sal);
            },
            stream: bufferToStream(buff),
        };
        return Promise.resolve(sal);
    }

    private async transformBuffer(publication: Publication, _link: Link, data: Buffer): Promise<Buffer> {

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

    // private async getDecryptedSizeStream(
    //     publication: Publication, link: Link,
    //     stream: IStreamAndLength): Promise<number> {
    //     let sal: IStreamAndLength;
    //     try {
    //         sal = await this.transformStream(publication, link, stream, false, 0, 0);
    //     } catch (err) {
    //         console.log(err);
    //         return Promise.reject("WTF?");
    //     }
    //     return Promise.resolve(sal.length);
    // }

    // public async getDecryptedSizeBuffer(publication: Publication, link: Link, data: Buffer): Promise<number> {
    //     let buff: Buffer;
    //     try {
    //         buff = await this.transformBuffer(publication, link, data);
    //     } catch (err) {
    //         console.log(err);
    //         return Promise.reject("WTF?");
    //     }
    //     return Promise.resolve(buff.length);
    // }
}

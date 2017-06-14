import {
    XmlItemType,
    XmlObject,
    XmlXPathSelector,
} from "@utils/xml-js-mapper";
import { CipherData } from "./encryption-cypherdata";
import { KeyInfo } from "./encryption-keyinfo";
import { EncryptionMethod } from "./encryption-method";
import { EncryptionProperty } from "./encryption-property";

@XmlObject({
    ds: "http://www.w3.org/2000/09/xmldsig#",
    enc: "http://www.w3.org/2001/04/xmlenc#",
    encryption: "urn:oasis:names:tc:opendocument:xmlns:container",
    ns: "http://www.idpf.org/2016/encryption#compression",
})
export class EncryptedData {

    // XPATH ROOT: /encryption:encryption/enc:EncryptedData

    @XmlXPathSelector("enc:EncryptionMethod")
    public EncryptionMethod: EncryptionMethod;

    @XmlXPathSelector("ds:KeyInfo")
    public KeyInfo: KeyInfo;

    @XmlXPathSelector("enc:CipherData")
    public CipherData: CipherData;

    @XmlXPathSelector("enc:EncryptionProperties/enc:EncryptionProperty")
    @XmlItemType(EncryptionProperty)
    public EncryptionProperties: EncryptionProperty[];
}

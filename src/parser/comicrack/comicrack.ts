import {
    XmlItemType,
    XmlObject,
    XmlXPathSelector,
} from "@utils/xml-js-mapper";
import { Page } from "./comicrack-page";

@XmlObject({
    xsd: "http://www.w3.org/2001/XMLSchema",
    xsi: "http://www.w3.org/2001/XMLSchema-instance",
})
export class ComicInfo {

    // XPATH ROOT: /ComicInfo

    @XmlXPathSelector("Title")
    public Title: string;

    @XmlXPathSelector("Series")
    public Series: string;

    @XmlXPathSelector("Volume")
    public Volume: number;

    @XmlXPathSelector("Number")
    public Number: number;

    @XmlXPathSelector("Writer")
    public Writer: string;

    @XmlXPathSelector("Penciller")
    public Penciller: string;

    @XmlXPathSelector("Inker")
    public Inker: string;

    @XmlXPathSelector("Colorist")
    public Colorist: string;

    @XmlXPathSelector("ScanInformation")
    public ScanInformation: string;

    @XmlXPathSelector("Summary")
    public Summary: string;

    @XmlXPathSelector("Year")
    public Year: number;

    @XmlXPathSelector("PageCount")
    public PageCount: number;

    @XmlXPathSelector("Pages/Page")
    @XmlItemType(Page)
    public Pages: Page[];

    public ZipPath: string;
}

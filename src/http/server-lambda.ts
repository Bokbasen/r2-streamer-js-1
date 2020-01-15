import * as debug_ from "debug";

import { createServer, proxy } from "aws-serverless-express";

import { Context } from "aws-lambda";
import { Server } from "./server";

debug_.enable("*");

const debug = debug_("r2:streamer#http/server-lambda");
debug.log = console.info.bind(console);

const server = new Server({
    disableOPDS: true,
    disableReaders: true,
    maxPrefetchLinks: 1,
});

const isInLambda =  !!(process.env.IS_LOCAL || false);
const app = server.getExpressApp();
const p = server.getPort(0);

if (!isInLambda) {
    const serverless = createServer(app);
    exports.handler = (event: any, context: Context) => proxy(serverless, event, context);
} else {
    app.listen(p, () => console.log(`Listening on ${p}`));
}

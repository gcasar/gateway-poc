import fs from 'fs'
import tls from 'tls'
import net from 'net'
import {resolveDownstreamPort} from "./dockerResolver.js";

const keypath = process.env.KEYPATH;
const port = parseInt(process.env.PORT) || 443;

const server = tls.createServer(
    {
        SNICallback: tlsServerNameHandler,
        key: fs.readFileSync(`${keypath}/privkey.pem`),
        cert: fs.readFileSync(`${keypath}/fullchain.pem`)
    },
    proxyHandler
);

server.listen(port);

function tlsServerNameHandler(domain, callback) {
    // only used to store the server name for which the connection was established
    // `this` refers to the current TLSSocket instance
    this.domain = domain;
    // signal no error and no custom context which uses the servers default context
    callback(null, null);
}

async function proxyHandler(tlsSocket) {
    try {
        const subdomain = tlsSocket.domain.split('.')[0];
        const targetPort = await resolveDownstreamPort(subdomain);
        const downstream = net.connect({
            port: targetPort || 80,
            host: '127.0.0.1'
        });

        // we need to explicitly handle all errors or the server explodes
        downstream.on('error', e => (console.error(e), tlsSocket.end()));
        tlsSocket.on('error', e => (console.error(e), downstream.end()));
        tlsSocket.pipe(downstream).pipe(tlsSocket);

        console.log({
            "action": "opened",
            "address": tlsSocket.remoteAddress,
            target: targetPort,
            "domain": tlsSocket.domain
        });

    } catch (e) {
        console.error(e);
        tlsSocket.end();
    }
}

import {jsonRequest} from "./jsonRequest.js";


export async function resolveDownstreamPort(name) {
    // list running docker containers
    const containers = await jsonRequest({socketPath: '/var/run/docker.sock', path: '/containers/json'});

    const nameToPort = containers
        .flatMap(extractMapping)
        .filter(Boolean)  // remove invalid mappings
        .reduce((acc, it) => (acc[it.name] = it.port, acc), {});  // map to name

    return nameToPort[name];
}

function extractMapping(it) {
    try {
        return {name: it.Names[0].substr(1), port: it.Ports[0]["PublicPort"]};
    } catch {
        return undefined
    }
}

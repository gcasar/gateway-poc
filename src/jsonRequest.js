import http from 'http'

/**
 * Util that collects and tries to parse a HTTP response as JSON
 * @param options see 'http.request' docs
 * @returns {Promise<unknown>}
 */
export async function jsonRequest(options) {
    return new Promise((resolve, reject) => {
        const req = http.request(options, handleConnected);
        req.on('error', reject);
        req.end();

        // collect all buffers from the stream
        const buffers = [];

        function handleConnected(stream) {
            stream.on('data', buffer => buffers.push(buffer));
            stream.on('end', handleEnd);
            stream.on('error', reject);
        }

        // try to parse from JSON
        function handleEnd() {
            let result;
            try {
                result = JSON.parse(Buffer.concat(buffers).toString());
            } catch (e) {
                reject(e);
                return;
            }
            resolve(result);
        }
    })
}

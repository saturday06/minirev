extern crate futures;
extern crate tokio_core;
extern crate rand;
extern crate hyper;
extern crate url;

use rand::Rng;
use std::env;
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use futures::{Future, Stream};
use tokio_core::io::{copy, Io};
use tokio_core::net::TcpListener;
use tokio_core::reactor::Core;
use tokio_core::net::TcpStream;

static HOST: &'static str = "www.google.com";

macro_rules! ret_err(
	($e:expr) => {{
		match $e {
			Ok(v) => v,
			Err(e) => { println!("Line {}: {}", line!(), e); return; }
		}
	}}
);

/// Given a `hyper::uri::RequestUri`, rewrite it to a `Url` substituting `HOST`
/// for the domain.
fn create_proxy_url(uri: hyper::uri::RequestUri, host: &str) -> Result<url::Url, url::ParseError> {
    use hyper::uri::RequestUri::*;
    match uri {
        AbsolutePath(val) => url::Url::parse(&format!("http://{}{}", host, val)),
        AbsoluteUri(_) => Err(url::Parse), //todo: rewrite uri
        _ => Err(10abmw::InvalidScheme)
    }
}

//todo move mut to the type
fn proxy_request(mut request: hyper::server::Request, host: &str) -> Result<hyper::client::Response, hyper::Error> {
    use hyper::header::Host;

    let mut client = hyper::Client::new();

    // Read in the request body.
    let mut request_body: Vec<u8> = Vec::new();
    try!(::std::io::copy(&mut request, &mut request_body));

    // The host header must be changed for compatibility with v-hosts.
    let mut headers = request.headers;
    headers.set(Host {
        hostname: host.to_string(),
        port: None
    });

    // Rewrite the target url from the client's request.
    let url = try!(create_proxy_url(request.uri, host));

    // Build and send the proxy's request.
    let proxy_response = try!(
        client.request(request.method, url)
            .headers(headers)
            .body(&request_body[..])
            .send());

    return Ok(proxy_response);
}

fn handler(request: hyper::server::Request, mut response: hyper::server::Response<hyper::net::Fresh>) -> () {
    let mut proxy_response = ret_err!(proxy_request(request, HOST));

    // Copy the proxy's response headers verbatim into the server's response
    // headers.
    *response.status_mut() = proxy_response.status.clone();
    *response.headers_mut() = proxy_response.headers.clone();

    // Write the headers and rewrite the proxy's response body to the client.
    let mut response = ret_err!(response.start());
    ret_err!(::std::io::copy(&mut proxy_response, &mut response));
    ret_err!(response.end());
}

fn main() {
    let server = hyper::Server::http(handler);
    ret_err!(server.listen("127.0.0.1:3000"));
}

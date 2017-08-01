extern crate futures;
extern crate hyper;
extern crate pretty_env_logger;
extern crate tokio_core;

use futures::future::FutureResult;
use hyper::{Get, StatusCode, Client};
use hyper::server::{Http, Service, Request, Response};
use std::string::String;
use tokio_core::reactor::Core;
use futures::Future;
use std::cell::{RefCell, RefMut};
use std::ascii::AsciiExt;
use futures::Stream;
use futures::stream::Map;
use hyper::Chunk;
use hyper::header::ContentLength;

fn to_uppercase(chunk: Chunk) -> Chunk {
    let uppered = chunk.iter()
        .map(|byte| byte.to_ascii_uppercase())
        .collect::<Vec<u8>>();
    Chunk::from(uppered)
}

fn handle(mut core: RefMut<Core>, req: Request) -> Response {
    let client = Client::new(&core.handle());
    match ("http://127.0.0.1:8080/".to_owned() + req.path()).parse() {
        Ok(uri) => core.run(client.get(uri).map(|upstream_res| {
            let headers = upstream_res.headers().clone();
            Response::new()
                // .with_headers(headers)
                .with_status(upstream_res.status())
                .with_body(upstream_res.body())
        })).unwrap_or(Response::new().with_status(StatusCode::BadGateway)),
        _ => Response::new().with_status(StatusCode::NotFound),
    }
}

struct Proxy {
}

impl Service for Proxy {
    type Request = Request;
    type Response = Response;
    type Error = hyper::Error;
    type Future = FutureResult<Response, hyper::Error>;

    fn call(&self, req: Request) -> Self::Future {
        futures::future::ok(match req.method() {
            &Get => {
                thread_local!(static CORE_CELL: RefCell<Core> = RefCell::new(Core::new().unwrap()));
                CORE_CELL.with(|core_cell| handle(core_cell.borrow_mut(), req))
            },
            _ => Response::new().with_status(StatusCode::NotFound),
        })
    }
}

fn start() -> Result<i32, String> {
    pretty_env_logger::init().map_err(|e|
        e.to_string()
    )?;
    let addr = "127.0.0.1:1337".parse().map_err(|e|
        format!("failed to parse address: {}", e)
    )?;
    let handler = || {
        Ok(Proxy{})
    };
    let server = Http::new().bind(&addr, handler).map_err(|e|
        format!("server.bind(): {}", e)
    )?;
    let local_addr = server.local_addr().map_err(|e|
        format!("server.local_addr(): {}", e)
    )?;
    println!("Listening on http://{} with 1 thread.", local_addr);
    server.run().map_err(|e|
        format!("server.run(): {}", e)
    )?;
    return Ok(0)
}

fn main() {
    match start() {
        Ok(n) => println!("ok: {}", n),
        Err(err) => println!("err: {}", err),
    }
}

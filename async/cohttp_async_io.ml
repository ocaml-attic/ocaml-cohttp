(*
 * Copyright (c) 2012-2013 Anil Madhavapeddy <anil@recoil.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
*)

open Core.Std
open Async.Std

let check_debug norm_fn debug_fn =
  try
    let _ = Sys.getenv_exn "COHTTP_DEBUG" in
    debug_fn
  with Failure _ ->
    norm_fn

type 'a t = 'a Deferred.t
let (>>=) = Deferred.(>>=)
let return = Deferred.return

type ic = Reader.t
type oc = Writer.t

let iter fn x =
  Deferred.List.iter x ~f:fn

let read_line =
  check_debug
    (fun ic ->
       Reader.read_line ic
       >>= function
       |`Ok s -> return (Some s)
       |`Eof -> return None
    )
    (fun ic ->
       Reader.read_line ic
       >>= function
       |`Ok s -> eprintf "<<< %s\n" s; return (Some s)
       |`Eof -> eprintf "<<<EOF\n"; return None
    )

let read ic len =
  let buf = String.create len in
  Reader.read ic ~len buf >>= function
  | `Ok len' -> return (String.sub buf 0 len')
  | `Eof -> return ""

let read_exactly ic len =
  let buf = String.create len in
  Reader.really_read ic ~pos:0 ~len buf >>=
  function
  |`Ok -> return (Some buf)
  |`Eof _ -> return None

let write =
  check_debug
    (fun oc buf ->
       Writer.write oc buf;
       return ())
    (fun oc buf ->
       eprintf "\n%4d >>> %s" (Pid.to_int (Unix.getpid ())) buf;
       Writer.write oc buf;
       return ())

let write_line oc buf =
  check_debug
    (fun oc buf ->
       Writer.write oc buf;
       Writer.write oc "\r\n";
       return ()
    )
    (fun oc buf ->
       eprintf "\n%4d >>>> %s\n" (Pid.to_int (Unix.getpid())) buf;
       Writer.write oc buf;
       Writer.write oc "\r\n";
       return ()
    )

let flush oc =
  Writer.flushed oc

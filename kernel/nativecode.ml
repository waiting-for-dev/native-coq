(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, *   INRIA - CNRS - LIX - LRI - PPS - Copyright 1999-2012     *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)
open Errors
open Term
open Names
open Declarations
open Util
open Nativevalues
open Nativelambda
open Pre_env
open Sign

(** Local names {{{**)

type lname = { lname : name; luid : int }

let dummy_lname = { lname = Anonymous; luid = -1 }

module LNord = 
  struct 
    type t = lname 
    let compare l1 l2 = l1.luid - l2.luid
  end
module LNmap = Map.Make(LNord)
module LNset = Set.Make(LNord)

let lname_ctr = ref (-1)

let reset_lname = lname_ctr := -1

let fresh_lname n = 
  incr lname_ctr;
  { lname = n; luid = !lname_ctr }
  (**}}}**)

(** Global names {{{ **)
type gname = 
  | Gind of string * inductive (* prefix, inductive name *)
  | Gconstruct of string * constructor (* prefix, constructor name *)
  | Gconstant of string * constant (* prefix, constant name *)
  | Gcase of label option * int
  | Gpred of label option * int
  | Gfixtype of label option * int
  | Gnorm of label option * int
  | Gnormtbl of label option * int
  | Ginternal of string
  | Gval of label option * int
  | Grel of int
  | Gnamed of identifier

let case_ctr = ref (-1)

let reset_gcase () = case_ctr := -1

let fresh_gcase l =
  incr case_ctr;
  Gcase (l,!case_ctr)

let pred_ctr = ref (-1)

let reset_gpred () = pred_ctr := -1

let fresh_gpred l = 
  incr pred_ctr;
  Gpred (l,!pred_ctr)

let fixtype_ctr = ref (-1)

let reset_gfixtype () = fixtype_ctr := -1

let fresh_gfixtype l =
  incr fixtype_ctr;
  Gfixtype (l,!fixtype_ctr)

let norm_ctr = ref (-1)

let reset_norm () = norm_ctr := -1

let fresh_gnorm l =
  incr norm_ctr;
  Gnorm (l,!norm_ctr)

let normtbl_ctr = ref (-1)

let reset_normtbl () = normtbl_ctr := -1

let fresh_gnormtbl l =
  incr normtbl_ctr;
  Gnormtbl (l,!normtbl_ctr)
  (**}}}**)

(** Symbols (pre-computed values) {{{**)

let val_ctr = ref (-1)

type symbol =
  | SymbValue of Nativevalues.t
  | SymbSort of sorts
  | SymbName of name
  | SymbConst of constant
  | SymbMatch of annot_sw
  | SymbInd of inductive

let get_value tbl i =
  match tbl.(i) with
    | SymbValue v -> v
    | _ -> anomaly "get_value failed"

let get_sort tbl i =
  match tbl.(i) with
    | SymbSort s -> s
    | _ -> anomaly "get_sort failed"

let get_name tbl i =
  match tbl.(i) with
    | SymbName id -> id
    | _ -> anomaly "get_name failed"

let get_const tbl i =
  match tbl.(i) with
    | SymbConst kn -> kn
    | _ -> anomaly "get_const failed"

let get_match tbl i =
  match tbl.(i) with
    | SymbMatch case_info -> case_info
    | _ -> anomaly "get_match failed"

let get_ind tbl i =
  match tbl.(i) with
    | SymbInd ind -> ind
    | _ -> anomaly "get_ind failed"

let symbols_list = ref ([] : symbol list)

let reset_symbols_list l =
  symbols_list := l;
  val_ctr := List.length l - 1

let push_symbol x =
  incr val_ctr;
  symbols_list := x :: !symbols_list;
  !val_ctr

let symbols_tbl_name = Ginternal "symbols_tbl"

let get_symbols_tbl () = Array.of_list (List.rev !symbols_list)
(**}}}**)

(** Lambda to Mllambda {{{**)

type prim_path = gname option 

type primitive =
  | Mk_prod
  | Mk_sort
  | Mk_ind
  | Mk_const
  | Mk_sw
  | Mk_fix         of rec_pos * int 
  | Mk_cofix       of int
  | Mk_rel         of int
  | Mk_var         of identifier
  | Is_accu
  | Is_int
  | Is_array
  | Is_resource 
  | Check_resource_name 
  | Cast_accu
  | Upd_cofix
  | Force_cofix
  | Val_to_int
  | Mk_uint
  | Val_of_bool

  (* Coq primitive with check *)
  | Chead0         of prim_path
  | Ctail0         of prim_path
  | Cadd           of prim_path
  | Csub           of prim_path
  | Cmul           of prim_path
  | Cdiv           of prim_path
  | Crem           of prim_path
  | Clsr           of prim_path
  | Clsl           of prim_path
  | Cand           of prim_path
  | Cor            of prim_path
  | Cxor           of prim_path
  | Caddc          of prim_path
  | Csubc          of prim_path
  | CaddCarryC     of prim_path
  | CsubCarryC     of prim_path
  | Cmulc          of prim_path
  | Cdiveucl       of prim_path
  | Cdiv21         of prim_path
  | CaddMulDiv     of prim_path
  | Ceqb_correct   of prim_path
  | Ceq            of prim_path
  | Clt            of prim_path
  | Cle            of prim_path
  | Clt_b 
  | Cle_b
  | Ccompare       of prim_path
  | Cprint         of prim_path

  | Carraymake     of prim_path
  | Carrayget      of prim_path
  | Carraydefault  of prim_path
  | Carrayset      of prim_path
  | Carraydestrset of prim_path
  | Carraycopy     of prim_path
  | Carrayreroot   of prim_path
  | Carraylength   of prim_path
  | Carrayinit     of prim_path
  | Carraymap      of prim_path

  | Cresourcemake  of prim_path
  | Cresourcegetc  of prim_path
  | Cresourcegeti  of prim_path

  | Cfoldi         of prim_path
  | Cfoldi_down    of prim_path
  (* Caml primitive *)
  | MLand
  | MLle
  | MLlt
  | MLinteq
  | MLlsl
  | MLlsr
  | MLland
  | MLlor
  | MLlxor
  | MLadd
  | MLsub
  | MLmul
  | MLmagic

type mllambda =
  | MLlocal        of lname 
  | MLglobal       of gname 
  | MLprimitive    of primitive
  | MLlam          of lname array * mllambda 
  | MLletrec       of (lname * lname array * mllambda) array * mllambda
  | MLlet          of lname * mllambda * mllambda
  | MLapp          of mllambda * mllambda array
  | MLif           of mllambda * mllambda * mllambda
  | MLmatch        of annot_sw * mllambda * (lname * mllambda) * mllam_branches
                              (* argument, accu branch, branches *)
  | MLconstruct    of string * constructor * mllambda array
                   (* prefix, constructor name, arguments *)
  | MLint          of int
  | MLuint         of Uint63.t
  | MLparray       of mllambda array
  | MLsetref       of string * mllambda
  | MLsequence     of mllambda * mllambda

and mllam_branches = ((constructor * lname option array) list * mllambda) array

let fv_lam l =
  let rec aux l bind fv =
    match l with
    | MLlocal l ->
	if LNset.mem l bind then fv else LNset.add l fv
    | MLglobal _ | MLprimitive _  | MLint _ | MLuint _ -> fv
    | MLlam (ln,body) ->
	let bind = Array.fold_right LNset.add ln bind in
	aux body bind fv
    | MLletrec(bodies,def) ->
	let bind = 
	  Array.fold_right (fun (id,_,_) b -> LNset.add id b) bodies bind in
	let fv_body (_,ln,body) fv =
	  let bind = Array.fold_right LNset.add ln bind in
	  aux body bind fv in
	Array.fold_right fv_body bodies (aux def bind fv)
    | MLlet(l,def,body) ->
	aux body (LNset.add l bind) (aux def bind fv)
    | MLapp(f,args) ->
	let fv_arg arg fv = aux arg bind fv in
	Array.fold_right fv_arg args (aux f bind fv)
    | MLif(t,b1,b2) ->
	aux t bind (aux b1 bind (aux b2 bind fv))
    | MLmatch(_,a,(x,p),bs) ->
      let fv = aux a bind fv in
      let fv = aux p (LNset.add x bind) fv in
      let fv_bs (cargs, body) fv =
	let bind = 
	  List.fold_right (fun (_,args) bind ->
	    Array.fold_right 
	      (fun o bind -> match o with 
	      | Some l -> LNset.add l bind 
	      | _ -> bind) args bind) 
	    cargs bind in
	aux body bind fv in
      Array.fold_right fv_bs bs fv
          (* argument, accu branch, branches *)
    | MLconstruct (_,_,p) | MLparray p -> 
	Array.fold_right (fun a fv -> aux a bind fv) p fv
    | MLsetref(_,l) -> aux l bind fv
    | MLsequence(l1,l2) -> aux l1 bind (aux l2 bind fv) in
  aux l LNset.empty LNset.empty

let is_int x = MLapp(MLprimitive Is_int, [|x|])
let is_array x = MLapp(MLprimitive Is_array, [|x|])
let is_resource x = MLapp(MLprimitive Is_resource, [|x|])
let mk_and t1 t2 = MLapp(MLprimitive MLand, [|t1; t2|])
let is_lt t1 t2 = MLapp(MLprimitive MLlt, [|t1; t2|])
let mk_add t1 t2 = MLapp(MLprimitive (Cadd None), [|t1; t2|])
let mk_int i = MLapp(MLprimitive Mk_uint, [|MLuint (Uint63.of_int i) |])

let rec mkMLlet x f1 f2 = 
  match f1 with
  | MLlet(y, fd, fb) ->
    MLlet(y,fd, mkMLlet x fd f2)
  | _ -> MLlet(x, f1, f2)

let mkMLlam params body =
  if Array.length params = 0 then body 
  else
    match body with
    | MLlam (params', body) -> MLlam(Array.append params params', body)
    | _ -> MLlam(params,body)

let mkMLapp f args =
  if Array.length args = 0 then f
  else
    match f with
    | MLapp(f,args') -> MLapp(f,Array.append args' args)
    | _ -> MLapp(f,args)

let empty_params = [||]

let decompose_MLlam c =
  match c with
  | MLlam(ids,c) -> ids,c
  | _ -> empty_params,c

(*s Global declaration *)
type global =
(*  | Gtblname of gname * identifier array *)
  | Gtblnorm of gname * lname array * mllambda array 
  | Gtblfixtype of gname * lname array * mllambda array
  | Glet of gname * mllambda
  | Gletcase of 
      gname * lname array * annot_sw * mllambda * (lname * mllambda) * mllam_branches
  | Gopen of string
  | Gtype of inductive * int array
    (* ind name, arities of constructors *)
  
let global_stack = ref ([] : global list)

let push_global_let gn body =
  global_stack := Glet(gn,body) :: !global_stack

let push_global_fixtype gn params body =
  global_stack := Gtblfixtype(gn,params,body) :: !global_stack

let push_global_norm name params body =
  global_stack := Gtblnorm(name, params, body)::!global_stack

let push_global_case name params annot a accu bs =
  global_stack := Gletcase(name,params, annot, a, accu, bs)::!global_stack

(*s Compilation environment *)

type env =
    { env_rel : mllambda list; (* (MLlocal lname) list *)
      env_bound : int; (* length of env_rel *)
      (* free variables *)
      env_urel : (int * mllambda) list ref; (* list of unbound rel *)
      env_named : (identifier * mllambda) list ref }

let empty_env () =
  { env_rel = [];
    env_bound = 0;
    env_urel = ref [];
    env_named = ref []
  }

let push_rel env id = 
  let local = fresh_lname id in
  local, { env with 
	   env_rel = MLlocal local :: env.env_rel;
	   env_bound = env.env_bound + 1
	 }

let push_rels env ids =
  let lnames, env_rel = 
    Array.fold_left (fun (names,env_rel) id ->
      let local = fresh_lname id in
      (local::names, MLlocal local::env_rel)) ([],env.env_rel) ids in
  Array.of_list (List.rev lnames), { env with 
			  env_rel = env_rel;
			  env_bound = env.env_bound + Array.length ids
			}

let get_rel env id i =
  if i <= env.env_bound then
    List.nth env.env_rel (i-1)
  else 
    let i = i - env.env_bound in
    try List.assoc i !(env.env_urel)
    with Not_found ->
      let local = MLlocal (fresh_lname id) in
      env.env_urel := (i,local) :: !(env.env_urel);
      local

let get_var env id =
  try List.assoc id !(env.env_named)
  with Not_found ->
    let local = MLlocal (fresh_lname (Name id)) in
    env.env_named := (id, local)::!(env.env_named);
    local
   
(*s Traduction of lambda to mllambda *)

let get_prod_name codom = 
  match codom with
  | MLlam(ids,_) -> ids.(0).lname
  | _ -> assert false

let get_lname (_,l) = 
  match l with
  | MLlocal id -> id
  | _ -> raise (Invalid_argument "Nativecode.get_lname")

let fv_params env = 
  let fvn, fvr = !(env.env_named), !(env.env_urel) in 
  let size = List.length fvn + List.length fvr in
  if size = 0 then empty_params 
  else begin
    let params = Array.make size dummy_lname in
    let fvn = ref fvn in
    let i = ref 0 in
    while !fvn <> [] do
      params.(!i) <- get_lname (List.hd !fvn);
      fvn := List.tl !fvn;
      incr i
    done;
    let fvr = ref fvr in
    while !fvr <> [] do
      params.(!i) <- get_lname (List.hd !fvr);
      fvr := List.tl !fvr;
      incr i
    done;
    params
  end

let generalize_fv env body = 
  mkMLlam (fv_params env) body

let empty_args = [||]

let fv_args env fvn fvr =
  let size = List.length fvn + List.length fvr in
  if size = 0 then empty_args 
  else 
    begin
      let args = Array.make size (MLint 0) in
      let fvn = ref fvn in
      let i = ref 0 in
      while !fvn <> [] do
	args.(!i) <- get_var env (fst (List.hd !fvn));
	fvn := List.tl !fvn;
	incr i
      done;
      let fvr = ref fvr in
      while !fvr <> [] do
	let (k,_ as kml) = List.hd !fvr in
	let n = get_lname kml in 
	args.(!i) <- get_rel env n.lname k;
	fvr := List.tl !fvr;
	incr i
      done;
      args
    end

let get_value_code i =
  MLapp (MLglobal (Ginternal "get_value"),
    [|MLglobal symbols_tbl_name; MLint i|])

let get_sort_code i =
  MLapp (MLglobal (Ginternal "get_sort"),
    [|MLglobal symbols_tbl_name; MLint i|])

let get_name_code i =
  MLapp (MLglobal (Ginternal "get_name"),
    [|MLglobal symbols_tbl_name; MLint i|])

let get_const_code i =
  MLapp (MLglobal (Ginternal "get_const"),
    [|MLglobal symbols_tbl_name; MLint i|])

let get_match_code i =
  MLapp (MLglobal (Ginternal "get_match"),
    [|MLglobal symbols_tbl_name; MLint i|])

let get_ind_code i =
  MLapp (MLglobal (Ginternal "get_ind"),
    [|MLglobal symbols_tbl_name; MLint i|])

type rlist =
  | Rnil 
  | Rcons of (constructor * lname option array) list ref * LNset.t * mllambda * rlist' 
and rlist' = rlist ref

let rm_params fv params = 
  Array.map (fun l -> if LNset.mem l fv then Some l else None) params 

let rec insert cargs body rl =
 match !rl with
 | Rnil ->
     let fv = fv_lam body in
     let (c,params) = cargs in
     let params = rm_params fv params in
     rl:= Rcons(ref [(c,params)], fv, body, ref Rnil)
 | Rcons(l,fv,body',rl) ->
     if body = body' then 
       let (c,params) = cargs in
       let params = rm_params fv params in
       l := (c,params)::!l
     else insert cargs body rl

let rec to_list rl =
  match !rl with
  | Rnil -> []
  | Rcons(l,_,body,tl) -> (!l,body)::to_list tl

let merge_branches t =
  let newt = ref Rnil in
  Array.iter (fun (c,args,body) -> insert (c,args) body newt) t;
  Array.of_list (to_list newt)

let mlprim_of_prim p o =
  match p with
  | Native.Int63head0       -> Chead0 o
  | Native.Int63tail0       -> Ctail0 o
  | Native.Int63add         -> Cadd o
  | Native.Int63sub         -> Csub o
  | Native.Int63mul         -> Cmul o
  | Native.Int63div         -> Cdiv o
  | Native.Int63mod         -> Crem o
  | Native.Int63lsr         -> Clsr o
  | Native.Int63lsl         -> Clsl o
  | Native.Int63land        -> Cand o
  | Native.Int63lor         -> Cor o
  | Native.Int63lxor        -> Cxor o
  | Native.Int63addc        -> Caddc o
  | Native.Int63subc        -> Csubc o
  | Native.Int63addCarryC   -> CaddCarryC o
  | Native.Int63subCarryC   -> CsubCarryC o
  | Native.Int63mulc        -> Cmulc o
  | Native.Int63diveucl     -> Cdiveucl o
  | Native.Int63div21       -> Cdiv21 o
  | Native.Int63addMulDiv   -> CaddMulDiv o
  | Native.Int63eq          -> Ceq o
  | Native.Int63lt          -> Clt o
  | Native.Int63le          -> Cle o
  | Native.Int63compare     -> Ccompare o
  | Native.Int63eqb_correct -> Ceqb_correct o 
      
let mlprim_of_cprim p kn =
  match p with
  | Native.Int63print      -> Cprint (Some kn)
  | Native.ArrayMake       -> Carraymake (Some kn)
  | Native.ArrayGet        -> Carrayget (Some kn)
  | Native.ArrayGetdefault -> Carraydefault (Some kn)
  | Native.ArraySet        -> Carrayset (Some kn)
  | Native.ArrayDestrSet   -> Carraydestrset (Some kn)
  | Native.ArrayCopy       -> Carraycopy (Some kn)
  | Native.ArrayReroot     -> Carrayreroot (Some kn)
  | Native.ArrayLength     -> Carraylength (Some kn)
  | Native.ArrayInit       -> Carrayinit (Some kn)
  | Native.ArrayMap        -> Carraymap (Some kn)
 
  | Native.ResourceMake    -> Cresourcemake (Some kn)
  | Native.ResourceGetc    -> Cresourcegetc (Some kn)
  | Native.ResourceGeti32  -> Cresourcegeti (Some kn)

let mlprim_of_iprim p kn =
  match p with
  | Native.Int63foldi      -> Cfoldi (Some kn)
  | Native.Int63foldi_down -> Cfoldi_down (Some kn)
  | Native.ArrayCreate     -> assert false  (* Should be inline before *)

(*type prim_aux = 
  | PAprim of (string * constant) option * Native.prim_op * prim_aux array
  (*| PAcprim of constant * Native.caml_prim * prim_aux array *)
  | PAml of mllambda

let add_check cond args =
  let aux cond a = 
    match a with
    | PAml(MLapp(MLprimitive Mk_uint, [|MLuint _|])) -> cond
    | PAml (MLuint _) -> cond
    | PAml ml -> if List.mem ml cond then cond else ml::cond 
    | _ -> cond
  in
  Array.fold_left aux cond args
  
let extract_prim ml_of l =
  let decl = ref [] in
  let cond = ref [] in
  let rec aux l = 
    match l with
    | Lprim(o,p,args) ->
	assert (p <> Native.Int63eqb_correct);
	let args = Array.map aux args in
	if o <> None then cond := add_check !cond args;
	PAprim(o,p,args)
    | Lrel _ | Lvar _ | Lint _ | Lval _ | Lconst _ -> PAml (ml_of l)
    | _ -> 
	let x = fresh_lname Anonymous in
	decl := (x,ml_of l)::!decl;
	PAml (MLlocal x) in
  let res = aux l in
  (!decl, !cond, res)

let app_prim p args = MLapp(MLprimitive p, args)

let mk_of_int i = i

let (*rec*) to_int v =
  match v with
  | MLint _ -> v 
(*  | MLapp(MLprimitive (MLlsl |  MLlsr | MLland | MLlor | MLlxor | MLadd | MLsub | MLmul), _) -> v *)
(*  | MLif(e,b1,b2) -> MLif(e,to_int b1, to_int b2) *)
  | _ -> MLapp(MLprimitive Val_to_int, [|v|]) 

let compile_prim decl cond paux =
  let rec opt_prim_aux paux =
    match paux with
    | PAprim(o, op, args) ->
	let args = Array.map opt_prim_aux args in
	begin match o, op with
	| None, Native.Int63lt -> app_prim Clt_b args
        | Some _, Native.Int63lt -> 
          app_prim (Clt None) args
	| None, Native.Int63le ->
          app_prim Cle_b args
        | Some _, Native.Int63le ->
          app_prim (Cle None) args
        (*	| _, Native.Int63eq -> mk_inteq (args_to_int args) *)
	| _, _ -> app_prim (mlprim_of_prim op None) args
	end
    | PAml ml -> ml 
  and naive_prim_aux paux = 
    match paux with
    | PAprim(o, op, args) ->
        app_prim (mlprim_of_prim op o) (Array.map naive_prim_aux args)
    | PAml ml -> ml in

  let compile_cond cond paux = 
    match cond with
    | [] -> opt_prim_aux paux 
    | [c1] ->
        MLif(app_prim Is_int [|c1|], opt_prim_aux paux, naive_prim_aux paux) 
    | c1::cond ->
	let cond = 
	  List.fold_left 
	    (fun ml c -> app_prim MLland [| ml; to_int c|])
            (app_prim MLland [|to_int c1; MLint 0|]) cond in
        let cond = app_prim MLmagic [|cond|] in
	MLif(cond, naive_prim_aux paux, opt_prim_aux paux) in
  let add_decl decl body =
    List.fold_left (fun body (x,d) -> MLlet(x,d,body)) body decl in
  add_decl decl (compile_cond cond paux)

let is_uint ml = 
  match ml with
  | MLapp(MLprimitive Mk_uint, [|MLuint _|]) -> true
  | MLuint _ -> true
  | _ -> false

let compile_cprim prefix kn p args =
  match p with
  | Native.ArrayGet when Array.length args = 3 -> 
      let t = fresh_lname Anonymous in
      let mlt = MLlocal t in
      let i = fresh_lname Anonymous in
      let mli = MLlocal i in
      let testt = MLapp(MLprimitive Is_array,[|mlt|]) in
      let test = 
        if is_uint args.(2) then testt 
        else
          MLapp(MLprimitive MLand,
                [|MLapp(MLprimitive Is_int,[|mli|]); testt |]) in

      MLlet(t, args.(1),
      MLlet(i, args.(2),
      MLif (test,
	    MLapp(MLprimitive (Carrayget None),[|mlt;mli|]),
	    MLapp(MLglobal (Gconstant (prefix, kn)),[|args.(0);mlt;mli|]))))
  | Native.ArraySet when Array.length args = 4 -> 
      let t = fresh_lname Anonymous in
      let mlt = MLlocal t in
      let i = fresh_lname Anonymous in
      let mli = MLlocal i in
      let v = fresh_lname Anonymous in
      let mlv = MLlocal v in
      let testt = MLapp(MLprimitive Is_array,[|mlt|]) in
      let test = 
        if is_uint args.(2) then testt 
        else
          MLapp(MLprimitive MLand,
                [|MLapp(MLprimitive Is_int,[|mli|]); testt |]) in
      MLlet(t, args.(1),
      MLlet(i, args.(2),
      MLlet(v, args.(3),
      MLif (test,
	    MLapp(MLprimitive (Carrayset None),[|mlt;mli;mlv|]),
	    MLapp(MLglobal (Gconstant (prefix, kn)),[|args.(0);mlt;mli;mlv|])))))
  | Native.ArrayDestrSet when Array.length args = 4 -> 
    let t = fresh_lname Anonymous in
    let mlt = MLlocal t in
    let i = fresh_lname Anonymous in
    let mli = MLlocal i in
    let v = fresh_lname Anonymous in
    let mlv = MLlocal v in
    let testt = MLapp(MLprimitive Is_array,[|mlt|]) in
    let test = 
      if is_uint args.(2) then testt 
      else
        MLapp(MLprimitive MLand,
              [|MLapp(MLprimitive Is_int,[|mli|]); testt |]) in
    MLlet(t, args.(1),
    MLlet(i, args.(2),
    MLlet(v, args.(3),
    MLif (test, 
       MLapp(MLprimitive (Carraydestrset None),[|mlt;mli;mlv|]),
       MLapp(MLglobal (Gconstant (prefix, kn)),[|args.(0);mlt;mli;mlv|])))))
  | _ ->
      MLapp(MLprimitive (mlprim_of_cprim p (prefix, kn)), args) *)

 let rec ml_of_lam env l t =
  match t with
  | Lrel(id ,i) -> get_rel env id i
  | Lvar id -> get_var env id
  | Lprod(dom,codom) ->
      let dom = ml_of_lam env l dom in
      let codom = ml_of_lam env l codom in
      let n = get_prod_name codom in
      let i = push_symbol (SymbName n) in
      MLapp(MLprimitive Mk_prod, [|get_name_code i;dom;codom|])
  | Llam(_, ids,body) ->
    let lnames,env = push_rels env ids in
    mkMLlam lnames (ml_of_lam env l body)
  | Lrec(id,body) ->
      let _, ids,body = decompose_Llam body in
      let lname, env = push_rel env id in
      let lnames, env = push_rels env ids in
      MLletrec([|lname, lnames, ml_of_lam env l body|], MLlocal lname)
  | Llet(id,def,body) ->
      let def = ml_of_lam env l def in
      let lname, env = push_rel env id in
      let body = ml_of_lam env l body in
      mkMLlet lname def body
  | Lapp(f,args) ->
      mkMLapp (ml_of_lam env l f) (Array.map (ml_of_lam env l) args)
  | Lconst (prefix,c) -> MLglobal(Gconstant (prefix,c))
  | Lprim (o,p,args) ->
    let p = mlprim_of_prim p (Option.map (fun (x1,x2) -> Gconstant(x1,x2)) o) in
    mkMLapp (MLprimitive p) (Array.map (ml_of_lam env l) args)
  | Lcprim (prefix,kn,p,args) ->
    let p = mlprim_of_cprim p (Gconstant (prefix, kn)) in
    mkMLapp (MLprimitive p) (Array.map (ml_of_lam env l) args)
  | Liprim (prefix,kn,p,args) ->
    let p = mlprim_of_iprim p (Gconstant (prefix, kn)) in
    mkMLapp(MLprimitive p) (Array.map (ml_of_lam env l) args)
  | Lcase (annot,p,a,bs) ->
      (* let predicate_uid fv_pred = compilation of p 
         let rec case_uid fv a_uid = 
           match a_uid with
           | Accu _ => mk_sw (predicate_uid fv_pred) (case_uid fv) a_uid
           | Ci argsi => compilation of branches 
         compile case = case_uid fv (compilation of a) *)
      (* Compilation of the predicate *)
         (* Remark: if we do not want to compile the predicate we 
            should a least compute the fv, then store the lambda representation
            of the predicate (not the mllambda) *)
      let env_p = empty_env () in
      let pn = fresh_gpred l in
      let mlp = ml_of_lam env_p l p in
      let mlp = generalize_fv env_p mlp in
      let (pfvn,pfvr) = !(env_p.env_named), !(env_p.env_urel) in
      push_global_let pn mlp; 
      (* Compilation of the case *)
      let env_c = empty_env () in
      let a_uid = fresh_lname Anonymous in
      let la_uid = MLlocal a_uid in
      (* compilation of branches *)
      let ml_br (c,params, body) = 
	let lnames, env = push_rels env_c params in
	(c, lnames, ml_of_lam env l body) in
      let bs = Array.map ml_br bs in
      let cn = fresh_gcase l in
      (* Compilation of accu branch *)
      let pred = MLapp(MLglobal pn, fv_args env_c pfvn pfvr) in  
      let (fvn, fvr) = !(env_c.env_named), !(env_c.env_urel) in
      let cn_fv = mkMLapp (MLglobal cn) (fv_args env_c fvn fvr) in
         (* remark : the call to fv_args does not add free variables in env_c *)
      let i = push_symbol (SymbMatch annot) in
      let accu =
        let x = fresh_lname Anonymous in
        let b = 
	  MLapp(MLprimitive Mk_sw,
	        [| get_match_code i; 
                   MLapp (MLprimitive Cast_accu, [|MLlocal x|]);
		   pred;
		   cn_fv |]) in
        (x,b) in
(*      let body = MLlam([|a_uid|], MLmatch(annot, la_uid, accu, bs)) in
      let case = generalize_fv env_c body in *)
      push_global_case cn 
	(Array.append (fv_params env_c) [|a_uid|]) 
        annot la_uid accu (merge_branches bs);

      (* Final result *)
      let arg = ml_of_lam env l a in
      let force =
	if annot.asw_finite then arg
	else MLapp(MLprimitive Force_cofix, [|arg|]) in
      mkMLapp (MLapp (MLglobal cn, fv_args env fvn fvr)) [|force|]
  | Lareint args -> 
      let res = ref (MLapp(MLprimitive Is_int, [|ml_of_lam env l args.(0)|]))in
      for i = 1 to Array.length args - 1 do
	let t = MLapp(MLprimitive Is_int, [|ml_of_lam env l args.(i)|]) in
	res := MLapp(MLprimitive MLand, [|!res;t|])
      done;
      !res
  | Lif(t,bt,bf) -> 
      MLif(ml_of_lam env l t, ml_of_lam env l bt, ml_of_lam env l bf)
  | Lfix ((rec_pos,start), (ids, tt, tb)) ->
      (* let type_f fvt = [| type fix |] 
         let norm_f1 fv f1 .. fn params1 = body1
	 ..
         let norm_fn fv f1 .. fn paramsn = bodyn
         let norm fv f1 .. fn = 
	    [|norm_f1 fv f1 .. fn; ..; norm_fn fv f1 .. fn|]
         compile fix = 
	   let rec f1 params1 = 
             if is_accu rec_pos.(1) then mk_fix (type_f fvt) (norm fv) params1
	     else norm_f1 fv f1 .. fn params1
           and .. and fn paramsn = 
	     if is_accu rec_pos.(n) then mk_fix (type_f fvt) (norm fv) paramsn
             else norm_fn fv f1 .. fv paramsn in
	   start
      *)
      (* Compilation of type *)
      let env_t = empty_env () in
      let ml_t = Array.map (ml_of_lam env_t l) tt in
      let params_t = fv_params env_t in
      let args_t = fv_args env !(env_t.env_named) !(env_t.env_urel) in
      let gft = fresh_gfixtype l in
      push_global_fixtype gft params_t ml_t;
      let mk_type = MLapp(MLglobal gft, args_t) in
      (* Compilation of norm_i *)
      let ndef = Array.length ids in
      let lf,env_n = push_rels (empty_env ()) ids in
      let t_params = Array.make ndef [||] in
      let t_norm_f = Array.make ndef (Gnorm (l,-1)) in
      let ml_of_fix i body =
	let _, idsi,bodyi = decompose_Llam body in
	let paramsi, envi = push_rels env_n idsi in
	t_norm_f.(i) <- fresh_gnorm l;
	let bodyi = ml_of_lam envi l bodyi in
	t_params.(i) <- paramsi;
	mkMLlam paramsi bodyi in
      let tnorm = Array.mapi ml_of_fix tb in
      let fvn,fvr = !(env_n.env_named), !(env_n.env_urel) in
      let fv_params = fv_params env_n in
      let fv_args' = Array.map (fun id -> MLlocal id) fv_params in
      let norm_params = Array.append fv_params lf in
      Array.iteri (fun i body ->
	push_global_let (t_norm_f.(i)) (mkMLlam norm_params body)) tnorm;
      let norm = fresh_gnormtbl l in
      push_global_norm norm fv_params 
         (Array.map (fun g -> mkMLapp (MLglobal g) fv_args') t_norm_f);
      (* Compilation of fix *)
      let fv_args = fv_args env fvn fvr in      
      let lf, env = push_rels env ids in
      let lf_args = Array.map (fun id -> MLlocal id) lf in
      let mk_norm = MLapp(MLglobal norm, fv_args) in
      let mkrec i lname = 
	let paramsi = t_params.(i) in
	let reci = MLlocal (paramsi.(rec_pos.(i))) in
	let pargsi = Array.map (fun id -> MLlocal id) paramsi in
	let body = 
	  MLif(MLapp(MLprimitive Is_accu,[|reci|]),
	       mkMLapp 
		 (MLapp(MLprimitive (Mk_fix(rec_pos,i)), 
			[|mk_type; mk_norm|]))
		 pargsi,
	       MLapp(MLglobal t_norm_f.(i), 
		     Array.concat [fv_args;lf_args;pargsi])) 
	in
	(lname, paramsi, body) in
      MLletrec(Array.mapi mkrec lf, lf_args.(start))
  | Lcofix (start, (ids, tt, tb)) -> 
      (* Compilation of type *)
      let env_t = empty_env () in
      let ml_t = Array.map (ml_of_lam env_t l) tt in
      let params_t = fv_params env_t in
      let args_t = fv_args env !(env_t.env_named) !(env_t.env_urel) in
      let gft = fresh_gfixtype l in
      push_global_fixtype gft params_t ml_t;
      let mk_type = MLapp(MLglobal gft, args_t) in
      (* Compilation of norm_i *) 
      let ndef = Array.length ids in
      let lf,env_n = push_rels (empty_env ()) ids in
      let t_params = Array.make ndef [||] in
      let t_norm_f = Array.make ndef (Gnorm (l,-1)) in
      let ml_of_fix i body =
	let _,idsi,bodyi = decompose_Llam body in
	let paramsi, envi = push_rels env_n idsi in
	t_norm_f.(i) <- fresh_gnorm l;
	let bodyi = ml_of_lam envi l bodyi in
	t_params.(i) <- paramsi;
	mkMLlam paramsi bodyi in
      let tnorm = Array.mapi ml_of_fix tb in
      let fvn,fvr = !(env_n.env_named), !(env_n.env_urel) in
      let fv_params = fv_params env_n in
      let fv_args' = Array.map (fun id -> MLlocal id) fv_params in
      let norm_params = Array.append fv_params lf in
      Array.iteri (fun i body ->
	push_global_let (t_norm_f.(i)) (mkMLlam norm_params body)) tnorm;
      let norm = fresh_gnormtbl l in
      push_global_norm norm fv_params 
        (Array.map (fun g -> mkMLapp (MLglobal g) fv_args') t_norm_f);
      (* Compilation of fix *)
      let fv_args = fv_args env fvn fvr in      
      let mk_norm = MLapp(MLglobal norm, fv_args) in
      let lnorm = fresh_lname Anonymous in
      let ltype = fresh_lname Anonymous in
      let lf, env = push_rels env ids in
      let lf_args = Array.map (fun id -> MLlocal id) lf in
      let upd i lname cont =
	let paramsi = t_params.(i) in
	let pargsi = Array.map (fun id -> MLlocal id) paramsi in
	let uniti = fresh_lname Anonymous in
	let body =
	  MLlam(Array.append paramsi [|uniti|],
		MLapp(MLglobal t_norm_f.(i),
		      Array.concat [fv_args;lf_args;pargsi])) in
	MLsequence(MLapp(MLprimitive Upd_cofix, [|lf_args.(i);body|]),
		   cont) in
      let upd = Util.array_fold_right_i upd lf lf_args.(start) in
      let mk_let i lname cont =
	mkMLlet lname
	  (MLapp(MLprimitive(Mk_cofix i),[| MLlocal ltype; MLlocal lnorm|]))
	  cont in
      let init = Util.array_fold_right_i mk_let lf upd in 
      mkMLlet lnorm mk_norm (mkMLlet ltype mk_type init)
  (*    	    
      let mkrec i lname = 
	let paramsi = t_params.(i) in
	let pargsi = Array.map (fun id -> MLlocal id) paramsi in
	let uniti = fresh_lname Anonymous in
	let body = 
	  MLapp( MLprimitive(Mk_cofix i),
		 [|mk_type;mk_norm; 
		   MLlam([|uniti|],
			 MLapp(MLglobal t_norm_f.(i),
			       Array.concat [fv_args;lf_args;pargsi]))|]) in
	(lname, paramsi, body) in
      MLletrec(Array.mapi mkrec lf, lf_args.(start)) *)
   
  | Lmakeblock (prefix,cn,_,args) ->
      MLconstruct(prefix,cn,Array.map (ml_of_lam env l) args)
  | Lconstruct (prefix, cn) ->
      MLglobal (Gconstruct (prefix, cn))
  | Lint i -> MLapp(MLprimitive Mk_uint, [|MLuint i|])
  | Lparray t -> MLparray(Array.map (ml_of_lam env l) t)
  | Lval v ->
      let i = push_symbol (SymbValue v) in get_value_code i
  | Lsort s ->
    let i = push_symbol (SymbSort s) in
    MLapp(MLprimitive Mk_sort, [|get_sort_code i|])
  | Lind (prefix, ind) -> MLglobal (Gind (prefix, ind))
  | Llazy -> MLglobal (Ginternal "lazy")
  | Lforce -> MLglobal (Ginternal "Lazy.force")

let mllambda_of_lambda auxdefs l t =
  let env = empty_env () in
  global_stack := auxdefs;
  let ml = ml_of_lam env l t in
  let fv_rel = !(env.env_urel) in
  let fv_named = !(env.env_named) in
  (* build the free variables *)
  let get_lname (_,t) = 
   match t with
   | MLlocal x -> x
   | _ -> assert false in
  let params = 
    List.append (List.map get_lname fv_rel) (List.map get_lname fv_named) in
  if params = [] then
    (!global_stack, ([],[]), ml)
  (* final result : global list, fv, ml *)
  else
    (!global_stack, (fv_named, fv_rel), mkMLlam (Array.of_list params) ml)
    (**}}}**)

(** Code optimization {{{**)

(** Optimization of match and fix *)

let can_subst l = 
  match l with
  | MLapp(MLprimitive Mk_uint, [|MLuint _|]) -> true
  | MLlocal _ | MLint _ | MLuint _ | MLglobal _ -> true
  | _ -> false

let subst s l =
  if LNmap.is_empty s then l 
  else
    let rec aux l =
      match l with
      | MLlocal id -> (try LNmap.find id s with _ -> l)
      | MLglobal _ | MLprimitive _ | MLint _ | MLuint _ -> l
      | MLlam(params,body) -> MLlam(params, aux body)
      | MLletrec(defs,body) ->
	let arec (f,params,body) = (f,params,aux body) in
	MLletrec(Array.map arec defs, aux body)
      | MLlet(id,def,body) -> MLlet(id,aux def, aux body)
      | MLapp(f,args) -> mkMLapp (aux f) (Array.map aux args)
      | MLif(t,b1,b2) -> MLif(aux t, aux b1, aux b2)
      | MLmatch(annot,a,(l,accu),bs) ->
	  let auxb (cargs,body) = (cargs,aux body) in
	  MLmatch(annot,aux a,(l,aux accu), Array.map auxb bs)
      | MLconstruct(prefix,c,args) -> MLconstruct(prefix,c,Array.map aux args)
      | MLparray p -> MLparray(Array.map aux p)
      | MLsetref(s,l1) -> MLsetref(s,aux l1) 
      | MLsequence(l1,l2) -> MLsequence(aux l1, aux l2)
    in
    aux l

let add_subst id v s = LNmap.add id v s

let subst_norm params args s =
  let len = Array.length params in
  assert (Array.length args = len && Util.array_for_all can_subst args);
  let s = ref s in
  for i = 0 to len - 1 do
    s := add_subst params.(i) args.(i) !s
  done;
  !s

let subst_case params args s =
  let len = Array.length params in
  let largs = Array.length args in
  assert (len > 0 && 
	  largs >= len && 
	  let r = ref true and i = ref 0 in
	  (* we test all arguments excepted the last *)
	  while !i < len - 1  && !r do r := can_subst args.(!i); incr i done;
	  !r);
  let s = ref s in
  for i = 0 to len - 1 do
    s := add_subst params.(i) args.(i) !s
  done;
  !s, if len = largs then [||] else Array.sub args len (largs - len)
    
let empty_gdef = Intmap.empty, Intmap.empty
let get_norm (gnorm, _) i = Intmap.find i gnorm
let get_case (_, gcase) i = Intmap.find i gcase

let all_lam n bs = 
  let f (_, l) = 
    match l with
    | MLlam(params, _) -> Array.length params = n
    | _ -> false in
  Util.array_for_all f bs

(* FIXME: improve this *)
let commutative_cut annot a (l,accu) bs args =
  (* FIXME introduce let for arg ? *)
  let mkb (c,b) =
     match b with
     | MLlam(params, body) -> 
         (c, Util.array_fold_left2 (fun body x v -> MLlet(x,v,body)) body params args)
     | _ -> assert false in
  MLmatch(annot, a, (l,mkMLapp accu args), Array.map mkb bs)

let optimize gdef l =   
  let rec inline s l =
    match l with
    | MLlocal id -> (try LNmap.find id s with _ -> l)
    | MLglobal _ | MLprimitive _ | MLint _ | MLuint _ -> l
    | MLlam(params,body) ->
        mkMLlam params (inline s body)
    | MLletrec(decls,body) ->
	let opt_rec (f,params,body) = (f,params,inline s body ) in 
	MLletrec(Array.map opt_rec decls, inline s body)
    | MLlet(id,def,body) ->
      mkMLlet id (inline s def) (inline s body)
    | MLapp(f, args) ->
	let oargs = Array.map (inline s) args in
	begin match f with
	| MLglobal (Gnorm (_,i)) ->
	  let params,body = get_norm gdef i in
	  let s = subst_norm params oargs s in
	  inline s body	    

	| MLglobal (Gcase (_,i)) ->
	  let params,body = get_case gdef i in
	  let s, extra = subst_case params oargs s in
          mkMLapp (inline s body) extra

        | MLprimitive (Cfoldi (Some kn)) when Array.length oargs >= 5 ->
          (* A f from to a extra *)
          (* f = fun i a extraparams => body *)
          (* 
             let ifrom = from in
             let ito   = to in
             if is_int iform && is_int ito then
               let rec aux i extraparams = 
                 f ifrom (if i < ito then aux (i+1) else a) extraparams in
               aux ito
             else accu args 
          *)
          let fparams, body = decompose_MLlam oargs.(1) in
          let nparams = Array.length fparams in
          let args' = Array.map (subst s) args in

          if nparams >= 2 then begin
            let _ifrom = fresh_lname (Name (id_of_string "ifrom"))  in
            let ifrom  = MLlocal _ifrom in
            let _i = fparams.(0) in 
            let  i  = MLlocal _i in
            let _ito = fresh_lname (Name (id_of_string "ito"))  in
            let ito  = MLlocal _ito in
            let _aux = fresh_lname (Name (id_of_string "aux")) in
            let aux = MLlocal _aux in
            let extraparams = Array.sub fparams 2 (nparams - 2) in
            let params = Array.append [|_i|] extraparams in
            let aux1 = MLapp(aux, [|mk_add i (mk_int 1)|]) in
            let args' = 
              let args' = Array.copy args' in
              args'.(2) <- ifrom;
              args'.(3) <- ito;
              args' in
             mkMLlet _ifrom oargs.(2)
            (mkMLlet _ito oargs.(3)
            (MLif(mk_and (is_int ifrom) (is_int ito),
               MLletrec ([|_aux, params, 
                 MLif(is_lt i ito,
                   subst (LNmap.add fparams.(1) aux1 LNmap.empty) body,
                 mkMLapp oargs.(4) (Array.map (fun x -> MLlocal x) extraparams))
               |],
               mkMLapp aux (Array.append [|ifrom|] 
                              (Array.sub oargs 5 (Array.length oargs - 5)))),
              MLapp(MLglobal kn, args'))))
          end else 
            MLapp(MLglobal kn, args') 
        (* FIXME : Add case for foldi_down *) 
	| _ -> mkMLapp (inline s f) oargs
	end 
    | MLif(t,b1,b2) ->
	let t = inline s t in
	let b2 = inline s b2 in
	begin match t, b2 with
	| MLapp(MLprimitive Is_accu,[| l1 |]), MLmatch(annot, l2, (x,_), bs)
	    when l1 = l2 -> MLmatch(annot, l1, (x,subst s b1), bs)	
        | _, _ -> MLif(t, inline s b1, b2)
	end
    | MLmatch(annot,a,(x,accu),bs) ->
	let inline_b (cargs,body) = (cargs,inline s body) in
	MLmatch(annot, inline s a, (x,subst s accu), Array.map inline_b bs)
    | MLconstruct(prefix,c,args) ->
        MLconstruct(prefix,c,Array.map (inline s) args)
    | MLparray p -> MLparray (Array.map (inline s) p)
    | MLsetref(r,l) -> MLsetref(r, inline s l) 
    | MLsequence(l1,l2) -> MLsequence(inline s l1, inline s l2)
  in
  let rec opt_app f args = 
    match f with
    | MLlet(x,f1,f2) ->
      mkMLlet x (opt_app f1 [||]) (opt_app f2 args)
    | MLlam(bds,body) ->
      let alen = Array.length args in
      if alen = 0 then mkMLlam bds (opt_app body args)
      else 
        let blen = Array.length bds in
        let len = min alen blen in
        let bd = Array.sub bds 0 len in
        let bd' = Array.sub bds len (blen - len) in
        let arg = Array.sub args 0 len in
        let arg' = Array.sub args len (alen - len) in
        let body = opt_app (mkMLlam bd' body) arg' in 
        Util.array_fold_right2 mkMLlet bd arg body
    | MLmatch(aw, a, (x,accu), br) ->
      let alen = Array.length args in
      if alen = 0 then 
        MLmatch(aw, opt_app a args, (x, accu), 
                Array.map (fun (c,body) -> c,opt_app body args) br)
      else
        let bd = Array.map (fun _ -> fresh_lname Anonymous) args in
        let args' = Array.map (fun x -> MLlocal x) bd in
        let body = 
          MLmatch(aw,opt_app a [||], (x, mkMLapp accu args'),
                  Array.map (fun (c,body) -> c, opt_app body args') br) in
         Util.array_fold_right2 mkMLlet bd args body
    | MLif(t,f1,f2) ->
      let alen = Array.length args in
      if alen = 0 then 
        MLif(opt_app t args, opt_app f1 args, opt_app f2 args)
      else 
        let bd = Array.map (fun _ -> fresh_lname Anonymous) args in
        let args' = Array.map (fun x -> MLlocal x) bd in
        let body = 
          MLif(opt_app t [||], opt_app f1 args', opt_app f2 args') in
         Util.array_fold_right2 mkMLlet bd args body
    | MLapp(f1,args') -> 
      let args' = Array.map (fun f -> opt_app f [||]) args' in
      opt_app f1 (Array.append args' args)
    | MLletrec (recs, body) ->
      MLletrec(Array.map (fun (n,b,body) -> (n,b,opt_app body [||])) recs,
               opt_app body args)
    | MLconstruct(n,c,args') ->
      assert (Array.length args = 0);
      MLconstruct(n,c, Array.map (fun f -> opt_app f [||]) args')
    | MLparray p -> 
      assert (Array.length args = 0); 
      MLparray (Array.map (fun f -> opt_app f [||]) p)
    | MLsetref (s,f) ->
      assert (Array.length args = 0);
      MLsetref (s, opt_app f [||])
    | MLsequence(f1,f2) ->
      MLsequence(opt_app f1 [||], opt_app f2 args) 
    | MLint _ |  MLuint _ -> assert (Array.length args = 0); f
    | MLlocal _ | MLglobal _ | MLprimitive _ ->
      mkMLapp f args in

  let rec remove_let s f = 
    match f with
    | MLlocal id -> (try LNmap.find id s with _ -> f)
    | MLglobal _ | MLprimitive _ | MLint _ | MLuint _ -> f
    | MLlam(params,body) -> MLlam(params, remove_let s body)
    | MLletrec(defs,body) ->
      let arec (f,params,body) = (f,params,remove_let s body) in
      MLletrec(Array.map arec defs, remove_let s body)
    | MLlet(id,def,body) -> 
      let def = remove_let s def in
      if can_subst def then remove_let (add_subst id def s) body
      else MLlet(id, def, remove_let s body)
    | MLapp(f,args) -> mkMLapp (remove_let s f) (Array.map (remove_let s) args)
    | MLif(t,b1,b2) -> MLif(remove_let s t, remove_let s b1, remove_let s b2)
    | MLmatch(annot,a,(l,accu),bs) ->
      let remove_letb (cargs,body) = (cargs,remove_let s body) in
      MLmatch(annot,remove_let s a, (l, subst s accu), 
              Array.map remove_letb bs)
    | MLconstruct(prefix,c,args) -> 
      MLconstruct(prefix,c,Array.map (remove_let s) args)
    | MLparray p -> MLparray(Array.map (remove_let s) p)
    | MLsetref(st,l1) -> MLsetref(st,remove_let s l1) 
    | MLsequence(l1,l2) -> MLsequence(remove_let s l1, remove_let s l2) in

  let l = inline LNmap.empty l in
  let l = opt_app l [||] in
  let l = remove_let LNmap.empty l in
  l

let optimize_stk stk =
  let add_global gdef g =
    match g with
    | Glet (Gnorm (_,i), body) ->
	let (gnorm, gcase) = gdef in
	(Intmap.add i (decompose_MLlam body) gnorm, gcase)
    | Gletcase(Gcase (_,i), params, annot,a,accu,bs) ->
	let (gnorm,gcase) = gdef in
	(gnorm, Intmap.add i (params,MLmatch(annot,a,accu,bs)) gcase)
    | Gletcase _ -> assert false
    | _ -> gdef in
  let gdef = List.fold_left add_global empty_gdef stk in
  let optimize_global g = 
    match g with
    | Glet(Gconstant (prefix, c), body) ->
        Glet(Gconstant (prefix, c), optimize gdef body)
    | _ -> g in
  List.map optimize_global stk
  (**}}}**)

(** Printing to ocaml {{{**)
(* Redefine a bunch of functions in module Names to generate names
   acceptable to OCaml. *)
let string_of_id s = ascii_of_ident (string_of_id s)
let string_of_label l = ascii_of_ident (string_of_label l)

let string_of_dirpath = function
  | [] -> "_"
  | sl -> String.concat "_" (List.map string_of_id (List.rev sl))

(* The first letter of the file name has to be a capital to be accepted by *)
(* OCaml as a module identifier.                                           *)
let string_of_dirpath s = "N"^string_of_dirpath s

let mod_uid_of_dirpath dir = string_of_dirpath (repr_dirpath dir)

let string_of_name x =
  match x with
    | Anonymous -> "anonymous" (* assert false *)
    | Name id -> string_of_id id

let string_of_label_def l =
  match l with
    | None -> ""
    | Some l -> string_of_label l

(* Relativization of module paths *)
let rec list_of_mp acc = function
  | MPdot (mp,l) -> list_of_mp (string_of_label l::acc) mp
  | MPfile dp ->
      let dp = repr_dirpath dp in
      string_of_dirpath dp :: acc
  | MPbound mbid -> ("X"^string_of_id (id_of_mbid mbid))::acc

let list_of_mp mp = list_of_mp [] mp

let string_of_kn kn =
  let (mp,dp,l) = repr_kn kn in
  let mp = list_of_mp mp in
  String.concat "_" mp ^ "_" ^ string_of_label l

let string_of_con c = string_of_kn (user_con c)
let string_of_mind mind = string_of_kn (user_mind mind)

let string_of_gname g =
  match g with
  | Gind (prefix, (mind, i)) ->
      Format.sprintf "%sindaccu_%s_%i" prefix (string_of_mind mind) i
  | Gconstruct (prefix, ((mind, i), j)) ->
      Format.sprintf "%sconstruct_%s_%i_%i" prefix (string_of_mind mind) i (j-1)
  | Gconstant (prefix, c) ->
      Format.sprintf "%sconst_%s" prefix (string_of_con c)
  | Gcase (l,i) ->
      Format.sprintf "case_%s_%i" (string_of_label_def l) i
  | Gpred (l,i) ->
      Format.sprintf "pred_%s_%i" (string_of_label_def l) i
  | Gfixtype (l,i) ->
      Format.sprintf "fixtype_%s_%i" (string_of_label_def l) i
  | Gnorm (l,i) ->
      Format.sprintf "norm_%s_%i" (string_of_label_def l) i
  | Ginternal s -> Format.sprintf "%s" s
  | Gnormtbl (l,i) -> 
      Format.sprintf "normtbl_%s_%i" (string_of_label_def l) i
  | Grel i ->
      Format.sprintf "rel_%i" i
  | Gnamed id ->
      Format.sprintf "named_%s" (string_of_id id)

let pp_gname fmt g =
  Format.fprintf fmt "%s" (string_of_gname g)

let pp_lname fmt ln =
  let s = ascii_of_ident (string_of_name ln.lname) in
  Format.fprintf fmt "x_%s_%i" s ln.luid

let pp_ldecls fmt ids =
  let len = Array.length ids in
  for i = 0 to len - 1 do
    Format.fprintf fmt " (%a : Nativevalues.t)" pp_lname ids.(i)
  done

let string_of_construct prefix ((mind,i),j) =
  let id = Format.sprintf "Construct_%s_%i_%i" (string_of_mind mind) i (j-1) in
  prefix ^ id
   
let pp_int fmt i =
  if i < 0 then Format.fprintf fmt "(%i)" i else Format.fprintf fmt "%i" i

let pp_mllam fmt l =

  let rec pp_mllam fmt l =
    match l with
    | MLlocal ln -> Format.fprintf fmt "@[%a@]" pp_lname ln
    | MLglobal g -> Format.fprintf fmt "@[%a@]" pp_gname g
    | MLprimitive p -> Format.fprintf fmt "@[%a@]" pp_primitive p
    | MLlam(ids,body) ->
	Format.fprintf fmt "@[(fun%a@ ->@\n %a)@]"
	  pp_ldecls ids pp_mllam body
    | MLletrec(defs, body) ->
	Format.fprintf fmt "@[%a@ in@\n%a@]" pp_letrec defs 
	  pp_mllam body
    | MLlet(id,def,body) ->
	Format.fprintf fmt "@[(let@ %a@ =@\n %a@ in@\n%a)@]"
          pp_lname id pp_mllam def pp_mllam body
    | MLapp(f, args) ->
	Format.fprintf fmt "@[%a@ %a@]" pp_mllam f (pp_args true) args
    | MLif(t,l1,l2) ->
	Format.fprintf fmt "@[(if %a then@\n  %a@\nelse@\n  %a)@]"
	  pp_mllam t pp_mllam l1 pp_mllam l2 
    | MLmatch (asw, c, (x, accu_br), br) ->
	let mind,i = asw.asw_ind in
        let prefix = asw.asw_prefix in
	let accu = 
          Format.sprintf "%sAccu_%s_%i" prefix (string_of_mind mind) i in
	Format.fprintf fmt 
	  "@[begin match Obj.magic (%a) with@\n| (%s _) as %a ->@\n  %a@\n%aend@]"
	  pp_mllam c 
          accu pp_mllam (MLlocal x) pp_mllam accu_br 
          (pp_branches prefix) br
	  
    | MLconstruct(prefix,c,args) ->
        Format.fprintf fmt "@[(Obj.magic (%s%a) : Nativevalues.t)@]" 
          (string_of_construct prefix c) pp_cargs args
    | MLint i -> pp_int fmt i
    | MLuint i -> Format.fprintf fmt "(%s)" (Uint63.compile i)
    | MLparray p ->
	Format.fprintf fmt "@[(parray_of_array@\n  [|";
	for i = 0 to Array.length p - 2 do
	  Format.fprintf fmt "%a;" pp_mllam p.(i)
	done;
	Format.fprintf fmt "%a|])@]" pp_mllam p.(Array.length p - 1)
    | MLsetref (s, body) ->
	Format.fprintf fmt "@[%s@ :=@\n %a@]" s pp_mllam body
    | MLsequence(l1,l2) ->
	Format.fprintf fmt "@[%a;@\n%a@]" pp_mllam l1 pp_mllam l2

  and pp_letrec fmt defs =
    let len = Array.length defs in
    let pp_one_rec i (fn, argsn, body) =
      Format.fprintf fmt "%a%a =@\n  %a"
	pp_lname fn 
	pp_ldecls argsn pp_mllam body in
    Format.fprintf fmt "@[let rec ";
    pp_one_rec 0 defs.(0);
    for i = 1 to len - 1 do
      Format.fprintf fmt "@\nand ";
      pp_one_rec i defs.(i)
    done;

  and pp_blam fmt l =
    match l with
    | MLprimitive (Mk_prod | Mk_sort) 
    | MLlam _ | MLletrec _ | MLlet _ | MLapp _ | MLif _ ->
	Format.fprintf fmt "(%a)" pp_mllam l
    | MLconstruct(_,_,args) when Array.length args > 0 ->
	Format.fprintf fmt "(%a)" pp_mllam l
    | _ -> pp_mllam fmt l

  and pp_args sep fmt args =
    let sep = if sep then " " else "," in
    let len = Array.length args in
    if len > 0 then begin
      Format.fprintf fmt "%a" pp_blam args.(0);
      for i = 1 to len - 1 do
	Format.fprintf fmt "%s%a" sep pp_blam args.(i)
      done
    end 

  and pp_cargs fmt args =
    let len = Array.length args in
    match len with
    | 0 -> ()
    | 1 -> Format.fprintf fmt " %a" pp_blam args.(0)
    | _ -> Format.fprintf fmt "(%a)" (pp_args false) args

  and pp_cparam fmt param = 
    match param with
    | Some l -> pp_mllam fmt (MLlocal l)
    | None -> Format.fprintf fmt "_"

  and pp_cparams fmt params =
    let len = Array.length params in
    match len with
    | 0 -> ()
    | 1 -> Format.fprintf fmt " %a" pp_cparam params.(0)
    | _ -> 
	let aux fmt params =
	  Format.fprintf fmt "%a" pp_cparam params.(0);
	  for i = 1 to len - 1 do
	    Format.fprintf fmt ",%a" pp_cparam params.(i)
	  done in 
	Format.fprintf fmt "(%a)" aux params

  and pp_branches prefix fmt bs =
    let pp_branch (cargs,body) =
      let pp_c fmt (cn,args) = 
        Format.fprintf fmt "| %s%a " 
      (string_of_construct prefix cn) pp_cparams args in
      let rec pp_cargs fmt cargs =
        match cargs with
    | [] -> ()
    | cargs::cargs' -> 
        Format.fprintf fmt "%a%a" pp_c cargs pp_cargs cargs' in
      Format.fprintf fmt "%a ->@\n  %a@\n" 
    pp_cargs cargs pp_mllam body
      in
    Array.iter pp_branch bs

  and pp_vprim o s = 
    match o with
    | None -> Format.fprintf fmt "%s" s
    | Some gn -> Format.fprintf fmt "%a" pp_mllam (MLglobal gn)

  and pp_primitive fmt = function
    | Mk_prod -> Format.fprintf fmt "mk_prod_accu" 
    | Mk_sort -> Format.fprintf fmt "mk_sort_accu"
    | Mk_ind -> Format.fprintf fmt "mk_ind_accu"
    | Mk_const -> Format.fprintf fmt "mk_constant_accu"
    | Mk_sw -> Format.fprintf fmt "mk_sw_accu"
    | Mk_fix(rec_pos,start) -> 
	let pp_rec_pos fmt rec_pos = 
	  Format.fprintf fmt "@[[| %i" rec_pos.(0);
	  for i = 1 to Array.length rec_pos - 1 do
	    Format.fprintf fmt "; %i" rec_pos.(i) 
	  done;
	  Format.fprintf fmt " |]@]" in
	Format.fprintf fmt "mk_fix_accu %a %i" pp_rec_pos rec_pos start
    | Mk_cofix(start) -> Format.fprintf fmt "mk_cofix_accu %i" start
    | Mk_rel i -> Format.fprintf fmt "mk_rel_accu %i" i
    | Mk_var id ->
        Format.fprintf fmt "mk_var_accu (Names.id_of_string \"%s\")" (string_of_id id)
    | Is_accu -> Format.fprintf fmt "is_accu"
    | Is_int -> Format.fprintf fmt "is_int"
    | Is_array -> Format.fprintf fmt "is_parray"
    | Is_resource -> Format.fprintf fmt "is_resource"
    | Check_resource_name -> Format.fprintf fmt "check_resource_name"
    | Cast_accu -> Format.fprintf fmt "cast_accu"
    | Upd_cofix -> Format.fprintf fmt "upd_cofix"
    | Force_cofix -> Format.fprintf fmt "force_cofix"
    | Val_to_int -> Format.fprintf fmt "val_to_int"
    | Mk_uint -> Format.fprintf fmt "mk_uint"
    | Val_of_bool -> Format.fprintf fmt "of_bool"
    | Chead0 o -> pp_vprim o "head0" 
    | Ctail0 o -> pp_vprim o "tail0"
    | Cadd o -> pp_vprim o "add"
    | Csub o -> pp_vprim o "sub"
    | Cmul o -> pp_vprim o "mul"
    | Cdiv o -> pp_vprim o "div"
    | Crem o -> pp_vprim o "rem"
    | Clsr o -> pp_vprim o "l_sr"
    | Clsl o -> pp_vprim o "l_sl"
    | Cand o -> pp_vprim o "l_and"
    | Cor o -> pp_vprim o "l_or"
    | Cxor o -> pp_vprim o "l_xor"
    | Caddc o -> pp_vprim o "addc"
    | Csubc o -> pp_vprim o "subc"
    | CaddCarryC o -> pp_vprim o "addCarryC"
    | CsubCarryC o -> pp_vprim o "subCarryC"
    | Cmulc o -> pp_vprim o "mulc"
    | Cdiveucl o -> pp_vprim o "diveucl"
    | Cdiv21 o -> pp_vprim o "div21"
    | CaddMulDiv o -> pp_vprim o "addMulDiv"
    | Ceqb_correct o -> pp_vprim o "eqb_correct"
    | Ceq o -> pp_vprim o "eq"
    | Clt o -> pp_vprim o "lt"
    | Cle o -> pp_vprim o "le"
    | Clt_b -> Format.fprintf fmt "lt_b"
    | Cle_b -> Format.fprintf fmt "le_b"
    | Ccompare o -> pp_vprim o "compare"
    | Cprint o -> pp_vprim o "print"
    | Carraymake o -> pp_vprim o "arraymake"
    | Carrayget o -> pp_vprim o "arrayget"
    | Carraydefault o -> pp_vprim o "arraydefault"
    | Carrayset o -> pp_vprim o "arrayset"
    | Carraydestrset o -> pp_vprim o "arraydestrset"
    | Carraycopy o -> pp_vprim o "arraycopy"
    | Carrayreroot o -> pp_vprim o "arrayreroot"
    | Carraylength o -> pp_vprim o "arraylength"
    | Carrayinit o -> pp_vprim o "arrayinit"
    | Carraymap o -> pp_vprim o "arraymap"
    | Cresourcemake o -> pp_vprim o "resourcemake"
    | Cresourcegetc o -> pp_vprim o "resourcegetc"
    | Cresourcegeti o -> pp_vprim o "resourcegeti"
    | Cfoldi o -> pp_vprim o "foldi"
    | Cfoldi_down o -> pp_vprim o "foldi_down"
	  (* Caml primitive *)
    | MLand -> Format.fprintf fmt "(&&)"
    | MLle -> Format.fprintf fmt "(<=)"
    | MLlt -> Format.fprintf fmt "lt_b"
    | MLinteq -> Format.fprintf fmt "(==)"
    | MLlsl -> Format.fprintf fmt "(lsl)"
    | MLlsr -> Format.fprintf fmt "(lsr)"
    | MLland -> Format.fprintf fmt "(land)"
    | MLlor -> Format.fprintf fmt "(lor)"
    | MLlxor -> Format.fprintf fmt "(lxor)"
    | MLadd -> Format.fprintf fmt "(+)"
    | MLsub -> Format.fprintf fmt "(-)"
    | MLmul -> Format.fprintf fmt "( * )"
    | MLmagic -> Format.fprintf fmt "Obj.magic"        

  in
  Format.fprintf fmt "@[%a@]" pp_mllam l
  
let pp_array fmt t =
  let len = Array.length t in
  Format.fprintf fmt "@[[|";
  for i = 0 to len - 2 do
    Format.fprintf fmt "%a; " pp_mllam t.(i)
  done;
  if len > 0 then
    Format.fprintf fmt "%a" pp_mllam t.(len - 1);
  Format.fprintf fmt "|]@]"
  
let pp_global fmt g =
  match g with
  | Glet (gn, c) ->
      let ids, c = decompose_MLlam c in
      Format.fprintf fmt "@[let %a%a =@\n  %a@]@\n@." pp_gname gn 
	pp_ldecls ids
	pp_mllam c
  | Gopen s ->
      Format.fprintf fmt "@[open %s@]@." s
  | Gtype ((mind, i), lar) ->
      let l = string_of_mind mind in
      let rec aux s ar = 
	if ar = 0 then s else aux (s^" * Nativevalues.t") (ar-1) in
      let pp_const_sig i fmt j ar =
        let sig_str = if ar > 0 then aux "of Nativevalues.t" (ar-1) else "" in
        Format.fprintf fmt "  | Construct_%s_%i_%i %s@\n" l i j sig_str
      in
      let pp_const_sigs i fmt lar =
        Format.fprintf fmt "  | Accu_%s_%i of Nativevalues.t@\n" l i;
        Array.iteri (pp_const_sig i fmt) lar
      in
      Format.fprintf fmt "@[type ind_%s_%i =@\n%a@]@\n@." l i (pp_const_sigs i) lar
  | Gtblfixtype (g, params, t) ->
      Format.fprintf fmt "@[let %a %a =@\n  %a@]@\n@." pp_gname g
	pp_ldecls params pp_array t
  | Gtblnorm (g, params, t) ->
      Format.fprintf fmt "@[let %a %a =@\n  %a@]@\n@." pp_gname g
	pp_ldecls params pp_array t 
  | Gletcase(g,params,annot,a,accu,bs) ->
      Format.fprintf fmt "@[let rec %a %a =@\n  %a@]@\n@."
	pp_gname g pp_ldecls params 
	pp_mllam (MLmatch(annot,a,accu,bs))(**}}}**)

(** Compilation of elements in environment {{{**)
let rec compile_with_fv env auxdefs l t =
  let (auxdefs,(fv_named,fv_rel),ml) = mllambda_of_lambda auxdefs l t in
  if fv_named = [] && fv_rel = [] then (auxdefs,ml)
  else apply_fv env (fv_named,fv_rel) auxdefs ml

and apply_fv env (fv_named,fv_rel) auxdefs ml =
  let get_rel_val (n,_) auxdefs =
    match !(lookup_rel_native_val n env) with
    | NVKnone ->
        compile_rel env auxdefs n
    | NVKvalue (v,d) -> assert false
  in
  let get_named_val (id,_) auxdefs =
    match !(lookup_named_native_val id env) with
    | NVKnone ->
        compile_named env auxdefs id
    | NVKvalue (v,d) -> assert false
  in
  let auxdefs = List.fold_right get_rel_val fv_rel auxdefs in
  let auxdefs = List.fold_right get_named_val fv_named auxdefs in
  let lvl = rel_context_length env.env_rel_context in
  let fv_rel = List.map (fun (n,_) -> MLglobal (Grel (lvl-n))) fv_rel in
  let fv_named = List.map (fun (id,_) -> MLglobal (Gnamed id)) fv_named in
  let aux_name = fresh_lname Anonymous in
  auxdefs, MLlet(aux_name, ml, mkMLapp (MLlocal aux_name) (Array.of_list (fv_rel@fv_named)))

and compile_rel env auxdefs n =
  let (_,body,_) = lookup_rel n env.env_rel_context in
  let n = rel_context_length env.env_rel_context - n in
  match body with
  | Some t ->
      let code = lambda_of_constr env t in
      let auxdefs,code = compile_with_fv env auxdefs None code in
      Glet(Grel n, code)::auxdefs
  | None -> 
      Glet(Grel n, MLprimitive (Mk_rel n))::auxdefs

and compile_named env auxdefs id =
  let (_,body,_) = lookup_named id env.env_named_context in
  match body with
  | Some t ->
      let code = lambda_of_constr env t in
      let auxdefs,code = compile_with_fv env auxdefs None code in
      Glet(Gnamed id, code)::auxdefs
  | None -> 
      Glet(Gnamed id, MLprimitive (Mk_var id))::auxdefs


let mk_lname s i = 
  let _x = { lname = Name (id_of_string s); luid = i} in
  _x, MLlocal _x

let mk_check param t p pargs n nargs = 
  MLlam(param, 
        MLif(t, MLapp (MLprimitive p, pargs), 
             MLapp(MLglobal n, nargs)))

let mk_array1 prim accu = 
  let _A, vA = mk_lname "vA" 0 in
  let _t, t = mk_lname "t" 1 in
  mk_check [|_A;_t|] (is_array t)
    prim [|t|]
    accu [|vA; t|]  

let compile_cprim accu cprim =
  match cprim with
  | Native.Int63print -> 
    let _x, x = mk_lname "x" 0 in
    let arg = [|x|] in
    mk_check [|_x|] (is_int x) 
      (Cprint None) arg 
      accu arg
 
  | Native.ArrayMake ->
    let _A, vA = mk_lname "vA" 0 in
    let _n, n = mk_lname "n" 1 in
    let _d, d= mk_lname "d" 2 in
    mk_check [|_A;_n;_d|] (is_int n) 
      (Carraymake None) [| n; d|] 
      accu [|vA; n; d|]

  | Native.ArrayGet ->
    let _A, vA = mk_lname "vA" 0 in
    let _t, t = mk_lname "t" 1 in
    let _n, n= mk_lname "n" 2 in
    mk_check [|_A;_t; _n|] (mk_and (is_array t) (is_int n))
      (Carrayget None) [|t; n|]
      accu [|vA; t; n|]
 
  | Native.ArraySet ->
    let _A, vA = mk_lname "vA" 0 in
    let _t, t = mk_lname "t" 1 in
    let _n, n = mk_lname "n" 2 in
    let _v, v = mk_lname "n" 3 in
    mk_check [|_A;_t; _n;_v|] (mk_and (is_array t) (is_int n))
      (Carrayset None) [|t; n; v|]
      accu [|vA; t; n; v|]

  | Native.ArrayDestrSet -> assert false

  | Native.ArrayGetdefault ->
    mk_array1 (Carraydefault None) accu

  | Native.ArrayCopy ->
    mk_array1 (Carraycopy None) accu

  | Native.ArrayReroot ->
    mk_array1 (Carrayreroot None) accu
    
  | Native.ArrayLength ->
    mk_array1 (Carraylength None) accu

  | Native.ArrayInit ->
    let _A, vA = mk_lname "vA" 0 in
    let _n, n = mk_lname "n" 1 in
    let _f, f = mk_lname "f" 2 in
    let _d, d = mk_lname "d" 3 in
    mk_check [|_A;_n; _f;_d|] (is_int n)
      (Carrayinit None) [|n; f; d|]
      accu [|vA; n; f; d|]
    
  | Native.ArrayMap ->
    let _A, vA = mk_lname "vA" 0 in
    let _B, vB = mk_lname "vB" 1 in
    let _f, f = mk_lname "f" 2 in
    let _t, t = mk_lname "t" 3 in
    mk_check [|_A;_B;_f;_t|] (is_array t)
      (Carraymap None) [|f;t|]
      accu [|vA;vB;f;t|]
  
  (* Resource Operations *)
  | Native.ResourceMake ->
    let _t, t = mk_lname "t" 0 in
    mk_check [|_t|] (MLapp(MLprimitive Check_resource_name, [|t|]))
      (Cresourcemake None) [|t|]
      accu [|t|]
    
  | Native.ResourceGetc ->
    let _r,r = mk_lname "r" 0 in
    let _n,n = mk_lname "n" 1 in
    mk_check [|_r;_n|] (mk_and (is_resource r) (is_int n))
      (Cresourcegetc None) [|r; n |]
      accu [|r; n|]
  | Native.ResourceGeti32 ->
    let _r,r = mk_lname "r" 0 in
    let _n,n = mk_lname "n" 1 in
    mk_check [|_r;_n|] (mk_and (is_resource r) (is_int n))
      (Cresourcegeti None) [|r; n |]
      accu [|r; n|]
    
let compile_iprim accu iprim = 
  match iprim with
  | Native.Int63foldi ->
    let _A, vA = mk_lname "_A" 0 in
    let _B, vB = mk_lname "_B" 1 in
    let _f, f  = mk_lname "f" 2 in
    let _min, min = mk_lname "min" 3 in
    let _max, max = mk_lname "max" 4 in
    let _cont, cont = mk_lname "cont" 5 in
    mk_check [|_A;_B;_f;_min;_max;_cont|] 
      (mk_and (is_int min) (is_int max))
      (Cfoldi None) [|f;min;max;cont|]
      accu [|vA;vB;f;min;max;cont|]
  | Native.Int63foldi_down ->
    let _A, vA = mk_lname "_A" 0 in
    let _B, vB = mk_lname "_B" 1 in
    let _f, f  = mk_lname "f" 2 in
    let _max, max = mk_lname "max" 4 in
    let _min, min = mk_lname "min" 3 in
    let _cont, cont = mk_lname "cont" 5 in
    mk_check [|_A;_B;_f;_max;_min;_cont|] 
      (mk_and (is_int min) (is_int max))
      (Cfoldi_down None) [|f;max;min;cont|]
      accu [|vA;vB;f;max;min;cont|]
      
  | Native.ArrayCreate -> assert false 

let mk_int1 prim accu = 
  let _x, x = mk_lname "x" 0 in
  mk_check [|_x|] (is_int x)
    prim [|x|]
    accu [|x|]  

let mk_int2 prim accu = 
  let _x, x = mk_lname "x" 0 in
  let _y, y = mk_lname "y" 1 in
  mk_check [|_x;_y|] (mk_and (is_int x) (is_int y))
    prim [|x;y|]
    accu [|x;y|]  

let compile_oprim accu oprim = 
  match oprim with
  | Native.Int63head0 -> mk_int1 (Chead0 None) accu
  | Native.Int63tail0 -> mk_int1 (Ctail0 None) accu

  | Native.Int63add -> mk_int2 (Cadd None) accu
  | Native.Int63sub -> mk_int2 (Csub None) accu
  | Native.Int63mul -> mk_int2 (Cmul None) accu
  | Native.Int63div -> mk_int2 (Cdiv None) accu
  | Native.Int63mod -> mk_int2 (Crem None) accu
  | Native.Int63lsr -> mk_int2 (Clsr None) accu
  | Native.Int63lsl -> mk_int2 (Clsl None) accu
  | Native.Int63land -> mk_int2 (Cand None) accu
  | Native.Int63lor  -> mk_int2 (Cor None) accu
  | Native.Int63lxor -> mk_int2 (Cxor None) accu

  | Native.Int63addc -> mk_int2 (Caddc None) accu
  | Native.Int63subc -> mk_int2 (Csubc None) accu
  | Native.Int63addCarryC -> mk_int2 (CaddCarryC None) accu
  | Native.Int63subCarryC -> mk_int2 (CsubCarryC None) accu

  | Native.Int63mulc -> mk_int2 (Cmulc None) accu
  | Native.Int63diveucl -> mk_int2 (Cdiveucl None) accu

  | Native.Int63div21 -> 
    let _x, x = mk_lname "x" 0 in
    let _y, y = mk_lname "y" 1 in
    let _z, z = mk_lname "z" 2 in
    mk_check [|_x;_y;_z|] (mk_and (is_int x) (mk_and (is_int y) (is_int z)))
      (Cdiv21 None) [|x;y;z|]
      accu [|x;y;z|]      

  | Native.Int63addMulDiv ->
    let _x, x = mk_lname "x" 0 in
    let _y, y = mk_lname "y" 1 in
    let _z, z = mk_lname "z" 2 in
    mk_check [|_x;_y;_z|] (mk_and (is_int x) (mk_and (is_int y) (is_int z)))
      (CaddMulDiv None) [|x;y;z|]
      accu [|x;y;z|]  
    
  | Native.Int63eq -> mk_int2 (Ceq None) accu 
  | Native.Int63lt -> mk_int2 (Clt None) accu
  | Native.Int63le -> mk_int2 (Cle None) accu
  | Native.Int63compare -> mk_int2 (Ccompare None) accu
  | Native.Int63eqb_correct -> 
    let _x, x = mk_lname "x" 0 in
    let _y, y = mk_lname "y" 1 in
    let _h, h = mk_lname "heq" 2 in
    MLlam(
      [|_x;_y;_h|], 
      MLif(
        is_int h, 
        h,
        MLapp(MLglobal accu, [|x;y;h|])))

let compile_prim accu p = 
  match p with
  | Native.Oprim p -> compile_oprim accu p
  | Native.Ocaml_prim p -> compile_cprim accu p
  | Native.Oiterator p -> compile_iprim accu p 

let compile_constant env prefix con body =
  match body with
  | Def t ->
      let t = Declarations.force t in
      let code = lambda_of_constr env t in
      let code, name =
        if is_lazy t then mk_lazy code, LinkedLazy prefix
        else code, Linked prefix
      in
      let l = con_label con in
      let auxdefs,code = compile_with_fv env [] (Some l) code in
      let l =
        optimize_stk (Glet(Gconstant ("",con),code)::auxdefs)
      in
      l, name
  | Primitive op when op <> Native.Oiterator Native.ArrayCreate -> 
   (* let accu = ... 
      let op = check_op accu ... 
      compilation optimise if ... then no_check_add ... else op ... *)

    let i = push_symbol (SymbConst con) in
    let l = Some (con_label con) in
    let n = fresh_gnorm l in
    let code = 
      [Glet(Gconstant ("", con), compile_prim n op);
       Glet(n, MLapp (MLprimitive Mk_const, [|get_const_code i|])) ] in
    code, Linked prefix
  | _ -> 
    let i = push_symbol (SymbConst con) in
    [Glet(Gconstant ("",con), MLapp (MLprimitive Mk_const, [|get_const_code i|]))],
    Linked prefix

let loaded_native_files = ref ([] : string list)

let register_native_file s =
  if not (List.mem s !loaded_native_files) then
    loaded_native_files := s :: !loaded_native_files

let is_code_loaded ~interactive name =
  match !name with
  | NotLinked -> false
  | LinkedInteractive s ->
      if (interactive && List.mem s !loaded_native_files) then true
      else (name := NotLinked; false)
  | LinkedLazy s | Linked s ->
   if List.mem s !loaded_native_files then true else (name := NotLinked; false)

let param_name = Name (id_of_string "params")
let arg_name = Name (id_of_string "arg")

let compile_mind prefix mb mind stack =
  let f i stack ob =
    let gtype = Gtype((mind, i), Array.map snd ob.mind_reloc_tbl) in
    let j = push_symbol (SymbInd (mind,i)) in
    let name = Gind ("", (mind, i)) in
    let accu =
      Glet(name, MLapp (MLprimitive Mk_ind, [|get_ind_code j|]))
    in
    let nparams = mb.mind_nparams in
    let params = 
      Array.init nparams (fun i -> {lname = param_name; luid = i}) in
    let add_construct j acc (_,arity) = 
      let args = Array.init arity (fun k -> {lname = arg_name; luid = k}) in 
      let c = (mind,i), (j+1) in
	  Glet(Gconstruct ("",c),
	     mkMLlam (Array.append params args)
	       (MLconstruct("", c, Array.map (fun id -> MLlocal id) args)))::acc
    in
    array_fold_left_i add_construct (gtype::accu::stack) ob.mind_reloc_tbl
  in
  let upd = (mb.mind_native_name, Linked prefix) in
  array_fold_left_i f stack mb.mind_packets, upd

type code_location_update =
    Declarations.native_name ref * Declarations.native_name
type code_location_updates =
  code_location_update Mindmap_env.t * code_location_update Cmap_env.t

type linkable_code = global list * code_location_updates

let empty_updates = Mindmap_env.empty, Cmap_env.empty

let compile_mind_deps env prefix ~interactive
    (comp_stack, (mind_updates, const_updates) as init) mind =
  let mib = lookup_mind mind env in
  if is_code_loaded ~interactive mib.mind_native_name
    || Mindmap_env.mem mind mind_updates
  then init
  else
    let comp_stack, upd = compile_mind prefix mib mind comp_stack in
    let mind_updates = Mindmap_env.add mind upd mind_updates in
    (comp_stack, (mind_updates, const_updates))

(* This function compiles all necessary dependencies of t, and generates code in
   reverse order, as well as linking information updates *)
let rec compile_deps env prefix ~interactive init t =
  match kind_of_term t with
  | Meta _ -> raise (Invalid_argument "Nativecode.get_deps: Meta")
  | Evar _ -> raise (Invalid_argument "Nativecode.get_deps: Evar")
  | Ind (mind,_) -> compile_mind_deps env prefix ~interactive init mind
  | Const c ->
      let c = get_allias env c in
      let cb = lookup_constant c env in
      let (_, (_, const_updates)) = init in
      if is_code_loaded ~interactive cb.const_native_name
        || (Cmap_env.mem c const_updates)
      then init
      else
      let comp_stack, (mind_updates, const_updates) as init = match cb.const_body with
        | Def t -> compile_deps env prefix ~interactive init (Declarations.force t)
        | _ -> init
      in
      let code, name = compile_constant env prefix c cb.const_body in
      let comp_stack = code@comp_stack in
      let const_updates = Cmap_env.add c (cb.const_native_name, name) const_updates in
      comp_stack, (mind_updates, const_updates)
  | Construct ((mind,_),_) -> compile_mind_deps env prefix ~interactive init mind
  | Case (ci, p, c, ac) ->
      let mind = fst ci.ci_ind in
      let init = compile_mind_deps env prefix ~interactive init mind in
      fold_constr (compile_deps env prefix ~interactive) init t
  | _ -> fold_constr (compile_deps env prefix ~interactive) init t

let compile_constant_field env prefix con (code, symb, (mupds, cupds)) cb =
  reset_symbols_list symb;
  let acc = (code, (mupds, cupds)) in
  match cb.const_body with
  | Def t ->
    let t = Declarations.force t in
    let (code, (mupds, cupds)) = compile_deps env prefix ~interactive:false acc t in
    let (gl, name) = compile_constant env prefix con cb.const_body in
    let cupds = Cmap_env.add con (cb.const_native_name, name) cupds in
    gl@code, !symbols_list, (mupds, cupds)
  | _ ->
    let (gl, name) = compile_constant env prefix con cb.const_body in
    let cupds = Cmap_env.add con (cb.const_native_name, name) cupds in
    gl@code, !symbols_list, (mupds, cupds)

let compile_mind_field prefix mp l (code, symb, (mupds, cupds)) mb =
  let mind = make_mind mp empty_dirpath l in
  reset_symbols_list symb;
  let code, upd = compile_mind prefix mb mind code in
  let mupds = Mindmap_env.add mind upd mupds in
  code, !symbols_list, (mupds, cupds)

let mk_open s = Gopen s

let mk_internal_let s code =
  Glet(Ginternal s, code)

(* ML Code for conversion function *)
let mk_conv_code env prefix t1 t2 =
  let gl, (mind_updates, const_updates) =
    let init = ([], empty_updates) in
    compile_deps env prefix ~interactive:true init t1
  in
  let gl, (mind_updates, const_updates) =
    let init = (gl, (mind_updates, const_updates)) in
    compile_deps env prefix ~interactive:true init t2
  in
  let gl = List.rev gl in
  let code1 = lambda_of_constr env t1 in
  let code2 = lambda_of_constr env t2 in
  let (gl,code1) = compile_with_fv env gl None code1 in
  let (gl,code2) = compile_with_fv env gl None code2 in
  let g1 = MLglobal (Ginternal "t1") in
  let g2 = MLglobal (Ginternal "t2") in
  let header = Glet(Ginternal "symbols_tbl",
    MLapp (MLglobal (Ginternal "get_symbols_tbl"),
      [|MLglobal (Ginternal "()")|])) in
  header::(gl@
  [mk_internal_let "t1" code1;
  mk_internal_let "t2" code2;
  Glet(Ginternal "_", MLsetref("rt1",g1));
  Glet(Ginternal "_", MLsetref("rt2",g2))]),
  (mind_updates, const_updates)

let mk_norm_code env prefix t =
  let gl, (mind_updates, const_updates) =
    let init = ([], empty_updates) in
    compile_deps env prefix ~interactive:true init t
  in
  let gl = List.rev gl in
  let code = lambda_of_constr env t in
  let (gl,code) = compile_with_fv env gl None code in
  let g1 = MLglobal (Ginternal "t1") in
  let header = Glet(Ginternal "symbols_tbl",
    MLapp (MLglobal (Ginternal "get_symbols_tbl"),
      [|MLglobal (Ginternal "()")|])) in
  header::(gl@
  [mk_internal_let "t1" code;
  Glet(Ginternal "_", MLsetref("rt1",g1))]), (mind_updates, const_updates)

let mk_library_header dir =
  let libname = Format.sprintf "(str_decode \"%s\")" (str_encode dir) in
  [Glet(Ginternal "symbols_tbl",
    MLapp (MLglobal (Ginternal "get_library_symbols_tbl"),
    [|MLglobal (Ginternal libname)|]))]

let update_location (r,v) = r := v

let update_locations (ind_updates,const_updates) =
  Mindmap_env.iter (fun _ -> update_location) ind_updates;
  Cmap_env.iter (fun _ -> update_location) const_updates
(** }}} **)

(* vim: set filetype=ocaml foldmethod=marker: *)

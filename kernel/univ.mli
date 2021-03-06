(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, *   INRIA - CNRS - LIX - LRI - PPS - Copyright 1999-2010     *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

(** Universes. *)

type universe_level
type universe

module UniverseLSet : Set.S with type elt = universe_level

(** The universes hierarchy: Type 0- = Prop <= Type 0 = Set <= Type 1 <= ... 
   Typing of universes: Type 0-, Type 0 : Type 1; Type i : Type (i+1) if i>0 *)

val type0m_univ : universe  (** image of Prop in the universes hierarchy *)
val type0_univ : universe  (** image of Set in the universes hierarchy *)
val type1_univ : universe  (** the universe of the type of Prop/Set *)

val make_universe_level : Names.dir_path * int -> universe_level
val make_universe : universe_level -> universe
val make_univ : Names.dir_path * int -> universe

val is_type0_univ : universe -> bool
val is_type0m_univ : universe -> bool
val is_univ_variable : universe -> bool

val universe_level : universe -> universe_level option
val compare_levels : universe_level -> universe_level -> int

(** The type of a universe *)
val super : universe -> universe

(** The max of 2 universes *)
val sup   : universe -> universe -> universe

(** {6 Graphs of universes. } *)

type universes

type check_function = universes -> universe -> universe -> bool
val check_leq : check_function
val check_eq : check_function

(** The empty graph of universes *)
val initial_universes : universes
val is_initial_universes : universes -> bool

(** {6 Constraints. } *)

type constraints

val empty_constraint : constraints
val union_constraints : constraints -> constraints -> constraints

val is_empty_constraint : constraints -> bool

type constraint_function = universe -> universe -> constraints -> constraints

val enforce_leq : constraint_function
val enforce_eq : constraint_function

(** {6 ... } *)
(** Merge of constraints in a universes graph.
  The function [merge_constraints] merges a set of constraints in a given
  universes graph. It raises the exception [UniverseInconsistency] if the
  constraints are not satisfiable. *)

type constraint_type = Lt | Le | Eq

exception UniverseInconsistency of constraint_type * universe * universe

val merge_constraints : constraints -> universes -> universes
val normalize_universes : universes -> universes
val sort_universes : universes -> universes

(** {6 Support for sort-polymorphic inductive types } *)

val fresh_local_univ : unit -> universe

val solve_constraints_system : universe option array -> universe array ->
  universe array

val subst_large_constraint : universe -> universe -> universe -> universe

val subst_large_constraints :
  (universe * universe) list -> universe -> universe

val no_upper_constraints : universe -> constraints -> bool

(** Is u mentionned in v (or equals to v) ? *)

val univ_depends : universe -> universe -> bool

(** {6 Pretty-printing of universes. } *)

val pr_uni_level : universe_level -> Pp.std_ppcmds
val pr_uni : universe -> Pp.std_ppcmds
val pr_universes : universes -> Pp.std_ppcmds
val pr_constraints : constraints -> Pp.std_ppcmds

(** {6 Dumping to a file } *)

val dump_universes :
  (constraint_type -> string -> string -> unit) ->
  universes -> unit

(** {6 Hash-consing } *)

val hcons_univlevel : universe_level -> universe_level
val hcons_univ : universe -> universe
val hcons_constraints : constraints -> constraints

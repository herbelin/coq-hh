(* Test apply in *)

Goal (forall x y, x = S y -> y=y) -> 2 = 4 -> 3=3.
intros H H0.
apply H in H0.
assumption.
Qed.

Require Import ZArith.
Goal (forall x y z, ~ z <= 0 -> x * z < y * z -> x <= y)%Z.
intros; apply Znot_le_gt, Zgt_lt in H.
apply Zmult_lt_reg_r, Zlt_le_weak in H0; auto.
Qed.

(* Test application under tuples *)

Goal (forall x, x=0 <-> 0=x) -> 1=0 -> 0=1.
intros H H'.
apply H in H'.
exact H'.
Qed.

(* Test as clause *)

Goal (forall x, x=0 <-> (0=x /\ True)) -> 1=0 -> True.
intros H H'.
apply H in H' as (_,H').
exact H'.
Qed.

(* Test application modulo conversion *)

Goal (forall x, id x = 0 -> 0 = x) -> 1 = id 0 -> 0 = 1.
intros H H'.
apply H in H'.
exact H'.
Qed.

(* Check apply/eapply distinction in presence of open terms *)

Parameter h : forall x y z : nat, x = z -> x = y.
Implicit Arguments h [[x] [y]].
Goal 1 = 0 -> True.
intro H.
apply h in H || exact I.
Qed.

Goal False -> 1 = 0.
intro H.
apply h || contradiction.
Qed.

(* Check if it unfolds when there are not enough premises *)

Goal forall n, n = S n -> False.
intros.
apply n_Sn in H.
assumption.
Qed.

(* Check naming in with bindings; printing used to be inconsistent before *)
(* revision 9450 *)

Notation S':=S (only parsing).
Goal (forall S, S = S' S) -> (forall S, S = S' S).
intros.
apply H with (S0 := S).
Qed.

(* Check inference of implicit arguments in bindings *)

Goal exists y : nat -> Type, y 0 = y 0.
exists (fun x => True).
trivial.
Qed.

(* Check universe handling in typed unificationn *)

Definition E := Type.
Goal exists y : E, y = y.
exists Prop.
trivial.
Qed.

Variable Eq : Prop = (Prop -> Prop) :> E.
Goal Prop.
rewrite Eq.
Abort.

(* Check insertion of coercions in bindings *)

Coercion eq_true : bool >-> Sortclass.
Goal exists A:Prop, A = A.
exists true.
trivial.
Qed.

(* Check use of unification of bindings types in specialize *)

Variable P : nat -> Prop.
Variable L : forall (l : nat), P l -> P l.
Goal P 0 -> True.
intros.
specialize L with (1:=H).
Abort.
Reset P.

(* Two examples that show that hnf_constr is used when unifying types
   of bindings (a simplification of a script from Field_Theory) *)

Require Import List.
Open Scope list_scope.
Fixpoint P (l : list nat) : Prop :=
  match l with
  | nil => True
  | e1 :: nil => e1 = e1
  | e1 :: l1 => e1 = e1 /\ P l1
  end.
Variable L : forall n l, P (n::l) -> P l.

Goal forall (x:nat) l, P (x::l) -> P l.
intros.
apply L with (1:=H).
Qed.

Goal forall (x:nat) l, match l with nil => x=x | _::_ => x=x /\ P l end -> P l.
intros.
apply L with (1:=H).
Qed.

(* The following call to auto fails if the type of the clause
   associated to the H is not beta-reduced [but apply H works]
   (a simplification of a script from FSetAVL) *)

Definition apply (f:nat->Prop) := forall x, f x.
Goal apply (fun n => n=0) -> 1=0.
intro H.
auto.
Qed.

(* The following fails if the coercion Zpos is not introduced around p
   before trying a subterm that matches the left-hand-side of the equality
   (a simplication of an example taken from Nijmegen/QArith) *)

Require Import ZArith.
Coercion Zpos : positive >-> Z.
Variable f : Z -> Z -> Z.
Variable g : forall q1 q2 p : Z, f (f q1 p) (f q2 p) = Z0.
Goal forall p q1 q2, f (f q1 (Zpos p)) (f q2 (Zpos p)) = Z0.
intros; rewrite g with (p:=p).
reflexivity.
Qed.

(* A funny example where the behavior differs depending on which of a
   multiple solution to a unification problem is chosen (an instance
   of this case can be found in the proof of Buchberger.BuchRed.nf_divp) *)

Definition succ x := S x.
Goal forall (I : nat -> Set) (P : nat -> Prop) (Q : forall n:nat, I n -> Prop),
  (forall x y, P x -> Q x y) ->
  (forall x, P (S x)) -> forall y: I (S 0), Q (succ 0) y.
intros.
apply H with (y:=y).
(* [x] had two possible instances: [S 0], coming from unifying the
   type of [y] with [I ?n] and [succ 0] coming from the unification with
   the goal; only the first one allows to make the next apply (which
   does not work modulo delta) working *)
apply H0.
Qed.

(* A similar example with a arbitrary long conversion between the two
   possible instances *)

Fixpoint compute_succ x :=
  match x with O => S 0 | S n => S (compute_succ n) end.

Goal forall (I : nat -> Set) (P : nat -> Prop) (Q : forall n:nat, I n -> Prop),
  (forall x y, P x -> Q x y) ->
  (forall x, P (S x)) -> forall y: I (S 100), Q (compute_succ 100) y.
intros.
apply H with (y:=y).
apply H0.
Qed.

(* Another example with multiple convertible solutions to the same
   metavariable (extracted from Algebra.Hom_module.Hom_module, 10th
   subgoal which precisely fails) *)

Definition ID (A:Type) := A.
Goal forall f:Type -> Type,
  forall (P : forall A:Type, A -> Prop),
  (forall (B:Type) x, P (f B) x -> P (f B) x) ->
  (forall (A:Type) x, P (f (f A)) x) ->
  forall (A:Type) (x:f (f A)), P (f (ID (f A))) x.
intros.
apply H.
(* The parameter [B] had two possible instances: [ID (f A)] by direct
   unification and [f A] by unification of the type of [x]; only the
   first choice makes the next command fail, as it was
   (unfortunately?) in Hom_module *)
try apply H.
unfold ID; apply H0.
Qed.

(* Test coercion below product and on non meta-free terms in with bindings *)
(* Cf wishes #1408 from E. Makarov *)

Parameter bool_Prop :> bool -> Prop.
Parameter r : bool -> bool -> bool.
Axiom ax : forall (A : Set) (R : A -> A -> Prop) (x y : A), R x y.

Theorem t : r true false.
apply ax with (R := r).
Qed.

(* Check verification of type at unification (submitted by Stéphane Lengrand):
   without verification, the first "apply" works what leads to the incorrect
   instantiation of x by Prop *)

Theorem u : ~(forall x:Prop, ~x).
unfold not.
intro.
eapply H.
apply (forall B:Prop,B->B) || (instantiate (1:=True); exact I).
Defined.

(* Fine-tuning coercion insertion in presence of unfolding (bug #1883) *)

Parameter name : Set.
Definition atom := name.

Inductive exp : Set :=
  | var : atom -> exp.

Coercion var : atom >-> exp.

Axiom silly_axiom : forall v : exp, v = v -> False.

Lemma silly_lemma : forall x : atom, False.
intros x.
apply silly_axiom with (v := x).  (* fails *)
reflexivity.
Qed.

(* Check that unification does not commit too early to a representative
   of an eta-equivalence class that would be incompatible with other
   unification constraints *)

Lemma eta : forall f : (forall P, P 1),
  (forall P, f P = f P) ->
   forall Q, f (fun x => Q x) = f (fun x => Q x).
intros.
apply H.
Qed.

(* Test propagation of evars from subgoal to brother subgoals *)

  (* This works because unfold calls clos_norm_flags which calls nf_evar *)

Lemma eapply_evar_unfold : let x:=O in O=x -> 0=O.
intros x H; eapply trans_equal;
[apply H | unfold x;match goal with |- ?x = ?x => reflexivity end].
Qed.

(* Test non-regression of (temporary) bug 1981 *)

Goal exists n : nat, True.
eapply ex_intro.
exact O.
trivial.
Qed.

(* Check pattern-unification on evars in apply unification *)

Lemma evar : exists f : nat -> nat, forall x, f x = 0 -> x = 0.
Proof.
eexists; intros x H.
apply H.
Qed.

(* Check that "as" clause applies to main premise only and leave the
   side conditions away *)

Lemma side_condition : 
  forall (A:Type) (B:Prop) x, (True -> B -> x=0) -> B -> x=x.
Proof.
intros.
apply H in H0 as ->.
reflexivity.
exact I.
Qed.

(* Check that "apply" is chained on the last subgoal of each lemma and
   that side conditions come first (as it is the case since 8.2) *)

Lemma chaining : 
  forall A B C : Prop,
  (1=1 -> (2=2 -> A -> B) /\ True) ->
  (3=3 -> (True /\ (4=4 -> C -> A))) -> C -> B.
Proof.
intros.
apply H, H0.
exact (refl_equal 1).
exact (refl_equal 2).
exact (refl_equal 3).
exact (refl_equal 4).
assumption.
Qed.

(* Check that the side conditions of "apply in", even when chained and
   used through conjunctions, come last (as it is the case for single
   calls to "apply in" w/o destruction of conjunction since 8.2) *)

Lemma chaining_in :
  forall A B C : Prop, 
  (1=1 -> True /\ (B -> 2=2 -> 5=0)) ->
  (3=3 -> (A -> 4=4 -> B) /\ True) -> A -> 0=5.
Proof.
intros.
apply H0, H in H1 as ->.
exact (refl_equal 0).
exact (refl_equal 1).
exact (refl_equal 2).
exact (refl_equal 3).
exact (refl_equal 4).
Qed.

(* From 12612, descent in conjunctions is more powerful *)
(* The following, which was failing badly in bug 1980, is now accepted
   (even if somehow surprising) *)

Goal True.
eapply ex_intro.
instantiate (2:=fun _ :True => True).
instantiate (1:=I).
exact I.
Qed.

(* The following, which were not accepted, are now accepted as
    expected by descent in conjunctions *)

Goal True.
eapply (ex_intro (fun _ => True) I).    
exact I.
Qed.

Goal True.
eapply (fun (A:Prop) (x:A) => conj I x).
exact I.
Qed.

(* The following was not accepted from r12612 to r12657 *)

Record sig0 := { p1 : nat; p2 : p1 = 0 }.

Goal forall x : sig0, p1 x = 0.
intro x;
apply x.
Qed.

(* The following worked in 8.2 but was not accepted from r12229 to
   r12926 because "simple apply" started to use pattern unification of
   evars. Evars pattern unification for simple (e)apply was disabled
   in 12927 but "simple eapply" below worked from 12898 to 12926
   because pattern-unification also started supporting abstraction
   over Metas. However it did not find the "simple" solution and hence
   the subsequent "assumption" failed. *)

Goal exists f:nat->nat, forall x y, x = y -> f x = f y.
intros; eexists; intros.
simple eapply (@f_equal nat).
assumption.
Existential 1 := fun x => x.
Qed.

(* The following worked in 8.2 but was not accepted from r12229 to
   r12897 for the same reason because eauto uses "simple apply". It
   worked from 12898 to 12926 because eauto uses eassumption and not
   assumption. *)

Goal exists f:nat->nat, forall x y, x = y -> f x = f y.
intros; eexists; intros.
eauto.
Existential 1 := fun x => x.
Qed.

(* The following was accepted before r12612 but is still not accepted in r12658

Goal forall x : { x:nat | x = 0}, proj1_sig x = 0.
intro x;
apply x.

*)

#use "pc.ml";;

exception X_not_yet_implemented;;
exception X_this_should_not_happen of string;;

let rec is_member a = function
  | [] -> false
  | a' :: s -> (a = a') || (is_member a s);;

let rec gcd a b =
  let a = Int.abs a in
  let b = Int.abs b in
  match (a, b) with
  | (0, b) -> b
  | (a, 0) -> a
  | (a, b) -> gcd b (a mod b);;

type scm_number =
  | ScmRational of (int * int)
  | ScmReal of float;;

type sexpr =
  | ScmVoid
  | ScmNil
  | ScmBoolean of bool
  | ScmChar of char
  | ScmString of string
  | ScmSymbol of string
  | ScmNumber of scm_number
  | ScmVector of (sexpr list)
  | ScmPair of (sexpr * sexpr);;

 module type READER = sig
  val nt_sexpr : sexpr PC.parser
  (* val print_sexpr : out_channel -> sexpr -> unit
  val print_sexprs : out_channel -> sexpr list -> unit
  val sprint_sexpr : 'a -> sexpr -> string
  val sprint_sexprs : 'a -> sexpr list -> string
  val scheme_sexpr_list_of_sexpr_list : sexpr list -> sexpr *)
end;; (*end of READER signature  *)

module Reader : READER = struct 
(* module Reader = struct *)
  open PC;;

  type string_part =
    | Static of string
    | Dynamic of sexpr;;

  let unitify nt = pack nt (fun _ -> ());;

  let make_maybe nt none_value =
  pack (maybe nt)
    (function
     | None -> none_value
     | Some(x) -> x)

  let make_make_skipped_star nt_skip_star (nt : 'a parser) =
    let nt1 = caten nt_skip_star (PC.caten nt nt_skip_star) in
    let nt1 = pack nt1 (fun (_, (e, _)) -> e) in
    nt1;;
  let rec nt_whitespace str =
    const (fun ch -> ch <= ' ') str
  and nt_end_of_line_or_file str = 
    let nt1 = unitify (char '\n') in
    let nt2 = unitify nt_end_of_input in
    let nt1 = disj nt1 nt2 in
    nt1 str
  and nt_line_comment str =
    let nt1 = char ';' in
    let nt2 = diff nt_any nt_end_of_line_or_file in
    let nt2 = star nt2 in
    let nt1 = caten nt1 nt2 in
    let nt1 = caten nt1 nt_end_of_line_or_file in
    let nt1 = unitify nt1 in
    nt1 str

  (* and nt_paired_comment str = 
    let nt0 = unitify (word "{}") in
    let nt1 = char '{' in
    let nt2 = star (const (fun ch -> (ch <> '}') && (ch <> '{'))) in
    let nt3 = star nt_paired_comment in
    let nt21 = star (const (fun ch -> (ch <> '}') && (ch <> '{'))) in
    let nt4 = char '}' in 
    let nt5 = caten nt1 (caten nt2 (caten nt3 (caten nt21 nt4))) in 
    let nt6 = unitify nt5 in
    let nt7 = disj nt0 nt6 in
    nt7 str  *)

  and nt_paired_comment str = 
    let nt1 = char '{' in
    let nt2 = const (fun ch -> (ch <> '}') && (ch <> '{')) in
    let nt2 = unitify nt2 in
    let nt3 = unitify nt_sexpr in
    let nt4 = disj nt3 nt2 in
    let nt5 = star nt4 in
    let nt6 = char '}' in
    let nt7 = caten nt1 (caten nt5 nt6) in 
    let nt7 = unitify nt7 in  
    nt7 str

  and nt_sexpr_comment str = 
    let nt1 = word "#;" in
    let nt2 = nt_sexpr in
    let nt3 = maybe nt_sexpr_comment in 
    let nt3 = caten nt1 (caten nt3 nt2) in
    let nt4 = unitify nt3 in
    nt4 str

  and nt_comment str =
    disj_list
      [nt_line_comment;
       nt_paired_comment;
       nt_sexpr_comment] str
  and nt_void str =
    let nt1 = word_ci "#void" in
    let nt1 = not_followed_by nt1 nt_symbol_char in
    let nt1 = pack nt1 (fun _ -> ScmVoid) in
    nt1 str
  and nt_skip_star str =
    let nt1 = disj (unitify nt_whitespace) nt_comment in
    let nt1 = unitify (star nt1) in
    nt1 str
  (* and make_skipped_star (nt : 'a parser) =
    let nt1 = caten nt_skip_star (caten nt nt_skip_star) in
    let nt1 = pack nt1 (fun (_, (e, _)) -> e) in
    nt1 *)
  and nt_digit str = 
    let nt1 = range '0' '9' in
    let nt1 = pack nt1 int_of_char in
    let nt1 = pack nt1 (fun (num) -> num -48) in
    nt1 str
  and nt_hex_digit str = 
  let nt1 = range '0' '9' in
  let nt1 = pack nt1 int_of_char in
  let nt1 = pack nt1 (fun (num) -> num -48) in
  let nt2 = range_ci 'a' 'f' in 
  let nt2 = pack nt2 int_of_char in
  let nt2 = pack nt2 (fun (num) -> num -55) in
  let nt3 = disj nt1 nt2 in 
  nt3 str
  and nt_nat str =   
    let nt1 = plus nt_digit in
    let nt1 = pack nt1
              (fun digits ->
                List.fold_left
                  (fun num digit ->
                    10 * num + digit)
                  0
                  digits) in
  nt1 str
  and nt_hex_nat str = 
    let nt1 = plus nt_hex_digit in
    let nt1 = pack nt1
                (fun digits ->
                  List.fold_left
                    (fun num digit ->
                      16 * num + digit)
                    0
                    digits) in
    nt1 str
  and nt_optional_sign str =
    let nt1 = char '+' in 
    let nt2 = char '-' in 
    let nt3 = disj nt1 nt2 in
    let nt4 = make_maybe nt3 '+' in
    let nt4 = pack nt4 (fun (c) -> if c=='+' then true else false) in
    nt4 str
  and nt_int str =
    let nt1 = caten nt_optional_sign nt_nat in
    let nt1 = pack nt1
                (fun (is_positive, n) ->
                  if is_positive then n else -n) in
    nt1 str
  and nt_frac str =
    let nt1 = caten nt_int (char '/') in
    let nt1 = pack nt1 (fun (num, _) -> num) in
    let nt2 = only_if nt_nat (fun n -> n != 0) in
    let nt1 = caten nt1 nt2 in
    let nt1 = pack nt1
                (fun (num, den) ->
                  let d = gcd num den in
                  ScmRational(num / d, den / d)) in
    nt1 str
  and nt_integer_part str =
    let nt1 = plus nt_digit in
    let nt1 = pack nt1
                (fun digits ->
                  List.fold_left
                    (fun num digit -> 10.0 *. num +. (float_of_int digit))
                    0.0
                    digits) in
    nt1 str
  and nt_mantissa str =
    let nt1 = plus nt_digit in
    let nt1 = pack nt1
                (fun digits ->
                  List.fold_right
                    (fun digit num ->
                      ((float_of_int digit) +. num) /. 10.0)
                    digits
                    0.0) in
    nt1 str
  and nt_exponent str =
    let nt1 = unitify (char_ci 'e') in
    let nt2 = word "*10" in
    let nt3 = unitify (word "**") in
    let nt4 = unitify (char '^') in
    let nt3 = disj nt3 nt4 in
    let nt2 = caten nt2 nt3 in
    let nt2 = unitify nt2 in
    let nt1 = disj nt1 nt2 in
    let nt1 = caten nt1 nt_int in
    let nt1 = pack nt1 (fun (_, n) -> float_of_int n) in
    let nt1 = pack nt1 (fun (n) -> Float.pow 10. n) in

    nt1 str

  and nt_floatA str = 
    let nt1 = caten nt_int (char '.') in
    let nt1 = pack nt1 (fun (n, _) -> n) in
    let nt2 = maybe nt_mantissa in
    let nt2 = pack nt2 (fun n -> match n with
      | None -> 0.0
      | Some(n) -> n) in
    let nt3 = maybe nt_exponent in
    let nt3 = pack nt3 (fun n -> match n with
      | None -> 1.0
      | Some(n) -> n) in
    let nt4 = caten nt1 (caten nt2 nt3) in
    let nt5 = pack nt4 (fun (n, (m,e)) -> ((float_of_int n) +. m) *. e) in 
    nt5 str
  and nt_floatB str =
    let nt1 = char '.' in
    let nt2 = caten nt1 nt_mantissa in
    let nt2 = pack nt2 (fun (_, m) ->  m) in
    let nt3 = maybe nt_exponent in
    let nt3 = pack nt3 (fun n -> match n with
    | None -> 1.0
    | Some(n) -> n) in
    let nt4 = caten nt2 nt3 in 
    let nt5 = pack nt4 (fun (m, e) -> m *. e) in
    nt5 str
  and nt_floatC str = 
    let nt1 = caten nt_integer_part nt_exponent in
    let nt1 = pack nt1 (fun (n, e) -> n *.e) in
    nt1 str

  and nt_float str = 
    let nt1 = disj_list [nt_floatA; nt_floatB; nt_floatC] in 
    let nt2 = caten nt_optional_sign nt1 in
    let nt2 = pack nt2
                (fun (is_positive, n) ->
                  if is_positive then n else -. n) in
    let nt3 = pack nt2 (fun (n) -> ScmReal (n)) in
    nt3 str
  and nt_number str =
    let nt1 = nt_float in
    let nt2 = nt_frac in
    let nt3 = pack nt_int (fun n -> ScmRational(n, 1)) in
    let nt1 = disj nt1 (disj nt2 nt3) in
    let nt1 = pack nt1 (fun r -> ScmNumber r) in
    let nt1 = not_followed_by nt1 nt_symbol_char in
    nt1 str  
  and nt_boolean str =
    let nt1 = char '#' in
    let nt2 = char_ci 'f' in
    let nt2 = pack nt2 (fun _ -> ScmBoolean false) in
    let nt3 = char_ci 't' in
    let nt3 = pack nt3 (fun _ -> ScmBoolean true) in
    let nt2 = disj nt2 nt3 in
    let nt1 = caten nt1 nt2 in
    let nt1 = pack nt1 (fun (_, value) -> value) in
    let nt2 = nt_symbol_char in
    let nt1 = not_followed_by nt1 nt2 in
    nt1 str
  and nt_char_simple str =
    let nt1 = const(fun ch -> ' ' < ch) in
    let nt1 = not_followed_by nt1 nt_symbol_char in
    nt1 str
    and nt_char_named str =
      let nt1 =
        disj_list [pack (word_ci "page") (fun _ -> '\012');
                  pack (word_ci "nul") (fun _ -> '\000');
                  pack (word_ci "newline") (fun _ -> '\n');
                  pack (word_ci "return") (fun _ -> '\r');
                  pack (word_ci "space") (fun _ -> ' ');
                  pack (word_ci "tab") (fun _ -> '\t')] in
      nt1 str
  and nt_char_hex str =
    let nt1 = caten (char_ci 'x') nt_hex_nat in
    let nt1 = pack nt1 (fun (_, n) -> n) in
    let nt1 = only_if nt1 (fun n -> n < 256) in
    let nt1 = pack nt1 (fun n -> char_of_int n) in
    nt1 str  
  and nt_char str =
    let nt1 = word "#\\" in
    let nt2 = disj nt_char_simple (disj nt_char_named nt_char_hex) in
    let nt1 = caten nt1 nt2 in
    let nt1 = pack nt1 (fun (_, ch) -> ScmChar ch) in
    nt1 str
  and nt_symbol_char str =
    let nt1 = range_ci 'a' 'z' in
    let nt1 = pack nt1 Char.lowercase_ascii in
    let nt2 = range '0' '9' in
    let nt3 = one_of "!$^*_-+=<>?/" in
    let nt1 = disj nt1 (disj nt2 nt3) in
    nt1 str
  and nt_symbol str = 
    let nt1 = plus nt_symbol_char in
    let nt2 = pack nt1 string_of_list in 
    let nt3 = pack nt2 (fun str ->  ScmSymbol str) in
    nt3 str
  and nt_string_part_simple str =
    let nt1 =
      disj_list [unitify (char '"'); unitify (char '\\'); unitify (word "~~");
                 unitify nt_string_part_dynamic] in
    let nt1 = diff nt_any nt1 in
    nt1 str
  and nt_string_part_meta str =
    let nt1 =
      disj_list [pack (word "\\\\") (fun _ -> '\\');
                 pack (word "\\\"") (fun _ -> '"');
                 pack (word "\\n") (fun _ -> '\n');
                 pack (word "\\r") (fun _ -> '\r');
                 pack (word "\\f") (fun _ -> '\012');
                 pack (word "\\t") (fun _ -> '\t');
                 pack (word "~~") (fun _ -> '~')] in
    nt1 str
  and nt_string_part_hex str =
    let nt1 = word_ci "\\x" in
    let nt2 = nt_hex_nat in
    let nt2 = only_if nt2 (fun n -> n < 256) in
    let nt3 = char ';' in
    let nt1 = caten nt1 (caten nt2 nt3) in
    let nt1 = pack nt1 (fun (_, (n, _)) -> n) in
    let nt1 = pack nt1 char_of_int in
    nt1 str
  and nt_string_part_dynamic str =
    let nt1 = word "~{" in
    let nt2 = word "}" in
    let nt3 = caten nt1 (caten nt_sexpr nt2) in
    let nt4 = pack nt3 (fun (_, (sexpr, _)) -> sexpr) in
    (* let nt4 = pack nt4 (fun (s1,s2)-> ScmPair(s1,s2)) in *)
    let nt5 = pack nt4 (fun sexpr -> 
                  ScmPair ((ScmSymbol "format"), 
                      (ScmPair ((ScmString "~a"), ScmPair (sexpr, ScmNil))))) in

    let nt6 = pack nt5 (fun str -> Dynamic(str)) in
    nt6 str

  and nt_string_part_static str =
    let nt1 = disj_list [nt_string_part_simple;
                         nt_string_part_meta;
                         nt_string_part_hex] in
    let nt1 = plus nt1 in
    let nt1 = pack nt1 string_of_list in
    let nt1 = pack nt1 (fun str -> Static str) in
    nt1 str
  and nt_string_part str =
    disj nt_string_part_static nt_string_part_dynamic str
  and nt_string str =
    let nt1 = char '"' in
    let nt2 = star nt_string_part in
    let nt3 = char '"' in
    let nt1 = caten nt1 (caten nt2 nt3) in
    let nt1 = pack nt1 (fun (_, (parts, _)) -> parts) in
    let nt1 = pack nt1
                (fun parts ->
                  match parts with
                  | [] -> ScmString ""
                  | [Static(str)] -> ScmString str
                  | [Dynamic(sexpr)] -> sexpr
                  | parts ->
                     let argl =
                       List.fold_right
                         (fun car cdr ->
                           ScmPair((match car with
                                    | Static(str) -> ScmString(str)
                                    | Dynamic(sexpr) -> sexpr),
                                   cdr))
                         parts
                         ScmNil in
                     ScmPair(ScmSymbol "string-append", argl)) in
    nt1 str
  and nt_vector str =  
    let nt1 = word "#(" in
    let nt1 = make_make_skipped_star nt_skip_star nt1 in
    let nt2 = star nt_sexpr  in
    let nt3 = char ')' in
    let nt4 = caten nt1 (caten nt2 nt3) in
    let nt5 = pack nt4 (fun (_, (sexprs, _)) -> sexprs) in
    let nt6 = pack nt5 (fun sexprs -> ScmVector sexprs) in
    let nt7 = caten (word "#( ") (char ')')in
    let nt8 = pack nt7 (fun _ -> ScmVector []) in
    let nt9 = disj nt8 nt6 in
    nt9 str
  
  and nt_list str = 
    let nt1 = char '(' in
    let nt1 = make_make_skipped_star nt_skip_star nt1 in
    let nt2 = star nt_sexpr in
    let nt3 = maybe (char '.') in
    let nt4 = make_maybe nt_sexpr ScmNil in
    let nt5 = char ')' in
    let nt6 = caten nt1 (caten nt2 (caten nt3 (caten nt4 nt5))) in
    let nt7 = pack nt6 (fun (_, (sexprs, (dot, (sexpr, _)))) -> (sexprs,sexpr)) in
    let nt8 = pack nt7 (fun (sexprs,sexpr) -> List.fold_right (fun car cdr -> ScmPair(car, cdr)) sexprs sexpr) in
    nt8 str
  and make_quoted_form nt_qf qf_name =
    let nt1 = caten nt_qf nt_sexpr in
    let nt1 = pack nt1
                (fun (_, sexpr) ->
                  ScmPair(ScmSymbol qf_name,
                          ScmPair(sexpr, ScmNil))) in
    nt1
  and nt_quoted_forms str =
    let nt1 =
      disj_list [(make_quoted_form (unitify (char '\'')) "quote");
                 (make_quoted_form (unitify (char '`')) "quasiquote");
                 (make_quoted_form
                    (unitify (not_followed_by (char ',') (char '@')))
                    "unquote");
                 (make_quoted_form (unitify (word ",@")) "unquote-splicing")] in
    nt1 str
  and nt_sexpr str = 
    let nt1 =
      disj_list [nt_void; nt_number; nt_boolean; nt_char; nt_symbol;
                 nt_string; nt_vector; nt_list; nt_quoted_forms] in 
    let nt1 = make_make_skipped_star nt_skip_star nt1 in
    nt1 str;;

  
end;; (* end of struct Reader *)

let rec string_of_sexpr = function
    | ScmVoid -> "#<void>"
    | ScmNil -> "()"
    | ScmBoolean(false) -> "#f"
    | ScmBoolean(true) -> "#t"
    | ScmChar('\n') -> "#\\newline"
    | ScmChar('\r') -> "#\\return"
    | ScmChar('\012') -> "#\\page"
    | ScmChar('\t') -> "#\\tab"
    | ScmChar(' ') -> "#\\space"
    | ScmChar(ch) ->
       if (ch < ' ')
       then let n = int_of_char ch in
            Printf.sprintf "#\\x%x" n
       else Printf.sprintf "#\\%c" ch
    | ScmString(str) ->
       Printf.sprintf "\"%s\""
         (String.concat ""
            (List.map
               (function
                | '\n' -> "\\n"
                | '\012' -> "\\f"
                | '\r' -> "\\r"
                | '\t' -> "\\t"
                | '\"' -> "\\\""
                | ch ->
                   if (ch < ' ')
                   then Printf.sprintf "\\x%x;" (int_of_char ch)
                   else Printf.sprintf "%c" ch)
               (list_of_string str)))
    | ScmSymbol(sym) -> sym
    | ScmNumber(ScmRational(0, _)) -> "0"
    | ScmNumber(ScmRational(num, 1)) -> Printf.sprintf "%d" num
    | ScmNumber(ScmRational(num, -1)) -> Printf.sprintf "%d" (- num)
    | ScmNumber(ScmRational(num, den)) -> Printf.sprintf "%d/%d" num den
    | ScmNumber(ScmReal(x)) -> Printf.sprintf "%f" x
    | ScmVector(sexprs) ->
       let strings = List.map string_of_sexpr sexprs in
       let inner_string = String.concat " " strings in
       Printf.sprintf "#(%s)" inner_string
    | ScmPair(ScmSymbol "quote",
              ScmPair(sexpr, ScmNil)) ->
       Printf.sprintf "'%s" (string_of_sexpr sexpr)
    | ScmPair(ScmSymbol "quasiquote",
              ScmPair(sexpr, ScmNil)) ->
       Printf.sprintf "`%s" (string_of_sexpr sexpr)
    | ScmPair(ScmSymbol "unquote",
              ScmPair(sexpr, ScmNil)) ->
       Printf.sprintf ",%s" (string_of_sexpr sexpr)
    | ScmPair(ScmSymbol "unquote-splicing",
              ScmPair(sexpr, ScmNil)) ->
       Printf.sprintf ",@%s" (string_of_sexpr sexpr)
    | ScmPair(car, cdr) ->
       string_of_sexpr' (string_of_sexpr car) cdr
  and string_of_sexpr' car_string = function
    | ScmNil -> Printf.sprintf "(%s)" car_string
    | ScmPair(cadr, cddr) ->
       let new_car_string =
         Printf.sprintf "%s %s" car_string (string_of_sexpr cadr) in
       string_of_sexpr' new_car_string cddr
    | cdr ->
       let cdr_string = (string_of_sexpr cdr) in
       Printf.sprintf "(%s . %s)" car_string cdr_string;;

let print_sexpr chan sexpr = output_string chan (string_of_sexpr sexpr);;

let print_sexprs chan sexprs =
  output_string chan
    (Printf.sprintf "[%s]"
        (String.concat "; "
          (List.map string_of_sexpr sexprs)));;

let sprint_sexpr _ sexpr = string_of_sexpr sexpr;;

let sprint_sexprs chan sexprs =
  Printf.sprintf "[%s]"
    (String.concat "; "
        (List.map string_of_sexpr sexprs));;

let scheme_sexpr_list_of_sexpr_list sexprs =
  List.fold_right (fun car cdr -> ScmPair (car, cdr)) sexprs ScmNil;;

let read str = (Reader.nt_sexpr str 0).found;;
(*
  This file is part of Gufo.

    Gufo is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Gufo is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Gufo. If not, see <http://www.gnu.org/licenses/>. 

    Author: Pierre Vittet
*)

(* The main language parser. *)

(*The compilation give a few conflicts:

Warning: 3 states have shift/reduce conflicts.
Warning: one state has reduce/reduce conflicts.
Warning: 3 shift/reduce conflicts were arbitrarily resolved.
Warning: 47 reduce/reduce conflicts were arbitrarily resolved.

They should be all about the '*' and '.' symbol.

This is because '*' is used for both '5 * 5' and 'ls *'.
And because '.' is used for variables/modules separation and for 'ls .''

Commenting the cmd_arg usage of STAR and DOT will solve the conflict but create
issue for commands such as 'ls *'.

*)

%{

  open GufoParsed

%}

%token STRUCT 
%token LET
%token FUN
(* %token JOKER (*_*) *)
%token COLON (* : *)
%token AFFECTATION (* = *)
%token TRUE 
%token FALSE
(* pattern matching *)
%token ARROW (* -> *)
%token WITH
%token WITH_SET 
%token WITH_MAP 
%token WITHOUT_SET
%token WITHOUT_MAP
(* file/dir shortcut *)
%token TILDE(* userdir *)
(* command rilated *)
%token CLOSING_CHEVRON (* > *)
%token EQ_CLOSING_CHEVRON (* >= *)
%token MINUS_CLOSING_CHEVRON 
%token DOUBLE_CLOSING_CHEVRON (* >> *)
%token WRITE_ERROR_TO (* 2> *)
%token WRITE_ERROR_NEXT_TO (* 2>> *)
%token WRITE_ERROR_TO_STD (* 2>&1 *)
%token WRITE_ALL_TO (* >& *)
%token OPENING_CHEVRON 
%token EQ_OPENING_CHEVRON 
%token MINUS_OPENING_CHEVRON 
%token PIPE
%token SIMPLE_AND
%token AND
%token OR
%token <string> ARG 
%token <string> FILE
(* %token <string> CMDARG *)
(* mathematic *)
%token PLUS
%token PLUS_DOT
%token PLUS_STR
%token MINUS
%token MINUS_DOT
%token DIVISION
%token DIVISION_DOT
%token STAR
%token STAR_DOT
%token MODULO
%token MODULO_DOT
%token EQUALITY (* == *)
%token INEQUALITY (* != *)
(*
%token GREATER_THAN (* gt *)
%token GREATER_OR_EQUAL (* gte *)
%token LOWER_THAN (* lt *)
%token LOWER_OR_EQUAL (* lte *)
*)
(* array rilated *)
%token OPEN_SQRBRACKET (* [ *)
%token OPEN_SQRIDXBRACKET (* [ *)
%token CLOSE_SQRBRACKET  (* ] *)
(* condition *)
%token IF
%token THEN
%token ELSE
(* type *)
%token INTTYPE 
%token FLOATTYPE
%token STRINGTYPE
%token LISTTYPE
%token SETTYPE
%token MAPTYPE
%token OPTIONTYPE
%token EXTENDS
%token IN
%token SHAS
%token MHAS
%token BOOLTYPE
%token CMDTYPE
%token <int> INT
%token <float> FLOAT 
%token <string>STRING 
(* others *)
%token OPEN_BRACE
%token CLOSE_BRACE
%token OPEN_BRACKET
%token CLOSE_BRACKET
%token SEMICOLON (* ; *)
%token <string> FREETYPE
%token <string> VARNAME 
%token <string> ENVVAR
%token <string> VARFIELD
%token <string> MODULVAR
%token <string> MODUL
%token <string> WORD 
%token DOUBLE_MINUS

%token DOT
%token NONE
%token SOME
%token START
%token COMMA
%token EOF

%token DOUBLE_SEMICOLON (* ;; *)
%left DOUBLE_SEMICOLON

%left PLUS
%left MINUS
%left STAR, DIVISION
%left MODULO
%left WITH
%left WITHOUT
%left SHAS
%left MHAS
%left PLUS_STR
%left PLUS_DOT
%left STAR_DOT, DIVISION_DOT
%left MODULO_DOT
%left WITH_SET
%left WITH_MAP
%left WITHOUT_SET
%left WITHOUT_MAP

%left SEMICOLON
%left SIMPLE_AND
%left AND
%left OR
%left PIPE


%right ELSE
(*
%left LOWER_THAN
%left LOWER_OR_EQUAL
%left GREATER_THAN
%left GREATER_OR_EQUAL
*)
%left TILDE


%start <mprogram option> prog
%start <mprogram option> shell
%%

(**
 ##################### MAIN LANGUAGE PARSER #####################
*)

shell:
    |  EOF
    {   
      Some {mpg_types = GenUtils.StringMap.empty; mpg_topvar = []; mpg_topcal = MSimple_val(MEmpty_val)} 
    }
    |  main_expr = topvarassign; EOF
    {   
      Some {mpg_types = GenUtils.StringMap.empty; mpg_topvar = []; mpg_topcal = main_expr} 
    }
    | LET ; varnames = var_tuple_decl; argnames = funargs_top ; AFFECTATION; funbody = topvarassign; EOF
	{
          let open GenUtils in 
          (match argnames, varnames with
            | [], _ -> 
              let mvar = {mva_name = varnames; mva_value = funbody} in
              Some ({mpg_types = GenUtils.StringMap.empty; mpg_topvar = [mvar];  mpg_topcal = MSimple_val(MEmpty_val)} )
            | argnames, MBaseDecl varname ->
                let mvar = {mva_name = MBaseDecl varname; mva_value = MSimple_val (MFun_val (List.rev argnames, funbody))} in
                Some ({mpg_types = GenUtils.StringMap.empty; mpg_topvar = [mvar];  mpg_topcal = MSimple_val(MEmpty_val)} )
            | argnames, MTupDecl _ -> 
                (*TODO: improve error message *)
                raise (VarError "Error, impossible to gives arguments to tuple element of a let declaration. ")
          )
      	}
    |  STRUCT; name = VARNAME; AFFECTATION; OPEN_BRACE ; fields_decl = fields_decl; CLOSE_BRACE
	{
          let open GenUtils in 
          let (typ, internal_val) = fields_decl in
          let name = rm_first_char name in
          let ctyp = 
                  (MComposed_type 
                              {mct_name = name; 
                               mct_fields = typ; 
                               mct_internal_val = internal_val})
          in
          Some {mpg_types = StringMap.singleton name ctyp; mpg_topvar = []; mpg_topcal = MSimple_val(MEmpty_val) } 
	}




prog:
    | p = mfile{ Some p }
;


mfile:
  |  topels = mtopels; EOF
    {
      let (types, variables) = topels in
      {mpg_types = types; mpg_topvar = variables;  mpg_topcal = MSimple_val(MEmpty_val)} 
    }
  |  topels = mtopels; START; main_expr = topvarassign;EOF
    {   
      let (types, variables) = topels in
      {mpg_types = types; mpg_topvar = variables; mpg_topcal = main_expr} 
    }


mtopels: 
  |topels = rev_mtypes_or_topvals {topels};


var_tuple_decl:
  | simple = base_var_tuple_decl;
    {simple}
  | left = base_var_tuple_decl; DOUBLE_MINUS ;right = var_tuple_decl ;
    {
     
      match left,right with
        | MBaseDecl lf, MBaseDecl rg -> MTupDecl [MBaseDecl lf;MBaseDecl rg]
        | MBaseDecl lf, MTupDecl rg -> MTupDecl ((MBaseDecl lf) :: rg)
        | MTupDecl lf,MBaseDecl rg ->  MTupDecl (List.rev(MBaseDecl rg :: (List.rev lf)))
        | MTupDecl lf, right ->  MTupDecl (List.rev(right :: (List.rev lf)))
    }
  | OPEN_BRACKET; decl = var_tuple_decl ; CLOSE_BRACKET
    {
     
     MTupDecl [decl]
    }

base_var_tuple_decl:
  | name = VARNAME; 
    {let open GenUtils in 
     
      let name = rm_first_char name in
      MBaseDecl (name)
    }

rev_mtypes_or_topvals:
  | { GenUtils.StringMap.empty,[] }
  | topels= rev_mtypes_or_topvals; STRUCT; name = VARNAME; AFFECTATION; OPEN_BRACE ; fields_decl = fields_decl; CLOSE_BRACE
	{
          let open GenUtils in 
	  let (types, topvals) = topels in
          let (typ, internal_val) = fields_decl in
          let name = rm_first_char name in
          match StringMap.mem name types with
            | true -> 
                raise (TypeError ("The type "^name^" is already declared."))
            | false ->
                ( GenUtils.StringMap.add name
                  (MComposed_type 
                              {mct_name = name; 
                               mct_fields = typ; 
                               mct_internal_val = internal_val})
                  types , topvals)
	}

  (*variables and function assignation*)

  | topels= rev_mtypes_or_topvals; LET ; varnames = var_tuple_decl; argnames = funargs_top ; AFFECTATION; funbody = topvarassign;
	{
           
          let open GenUtils in 
      	  let (types, topvals) = topels in
          (match argnames, varnames with
            | [], _ -> 
              let mvar = {mva_name = varnames; mva_value = funbody} in
      	      (  types ,  mvar :: topvals )
            | argnames, MBaseDecl varname ->
                let mvar = {mva_name = MBaseDecl varname; mva_value = MSimple_val (MFun_val (List.rev argnames, funbody))} in
      	      (  types ,  mvar :: topvals )
            | argnames, MTupDecl _ -> 
                (*TODO: improve error message *)
                raise (VarError "Error, impossible to gives arguments to tuple element of a let declaration. ")
          )
      	}

(* TYPE PARSING*)

fields_decl: 
  fields_internalfun = rev_fields_decl 
  {
  let (fields, internalfun) = fields_internalfun in
  (List.rev fields, List.rev internalfun )
  };

rev_fields_decl:
  | { [],[] }
  | vars = rev_fields_decl; varname = WORD ; COLON; typename = toptypedecl ; COMMA
    { 
      let lst_field, lst_val = vars in
      {mtf_name = varname; mtf_type = typename; mtf_extend = None} :: lst_field, lst_val }
  | vars = rev_fields_decl; EXTENDS; fieldname= modulVar; COMMA
    { 
      let lst_field, lst_val = vars in
      let fieldnameStr = ref_to_string fieldname in 
      { mtf_name = String.concat "_" ["ext"; fieldnameStr]; 
        mtf_type = (MRef_type fieldname);
        mtf_extend = Some fieldnameStr;
      } :: lst_field, 
      lst_val 
    }
  | vars = rev_fields_decl; EXTENDS; fieldname= modulVar; WITH; anofun = anonymousfun; COMMA
    { 
      let lst_field, lst_val = vars in
      let fieldnameStr = ref_to_string fieldname in 
      {mtf_name = String.concat "_" ["ext"; fieldnameStr]; 
       mtf_type = (MRef_type fieldname);
       mtf_extend = Some fieldnameStr
      } :: lst_field , 
     (String.concat "_" ["extfun"; fieldnameStr], anofun) ::lst_val }
  ;

toptypedecl:
  | ft = FREETYPE;
    {MAll_type ft }
  | STRINGTYPE
    { MBase_type MTypeString }
  | INTTYPE
    { MBase_type MTypeInt }
  | FLOATTYPE
    { MBase_type MTypeFloat }
  | BOOLTYPE
    { MBase_type MTypeBool }
  | CMDTYPE
    { MBase_type MTypeCmd }
  | internal_type = typedecl; LISTTYPE
    { MList_type internal_type }
  | args = funargdecl ; 
    { 
      let rev_args = List.rev args in
      let ret_type = List.hd rev_args in
      let args = List.rev (List.tl rev_args) in
      MFun_type (args, ret_type) }
  | name = modulVar
    { MRef_type name }
  | first_tupel = typedecl ; DOUBLE_MINUS; tupel_suite= typetupelseq;
    { MTuple_type (first_tupel:: tupel_suite)}
  | tdec = typedecl; OPTIONTYPE; 
    {MOption_type tdec}
  | tdec = typedecl ;SETTYPE
    { MSet_type tdec }
  | OPEN_BRACKET; tdec = typedecl; COMMA; tdec2 = typedecl; CLOSE_BRACKET ;MAPTYPE
    { MMap_type (tdec, tdec2)}


typedecl:
  | ft = FREETYPE;
    {MAll_type ft }
  | STRINGTYPE
    { MBase_type MTypeString }
  | INTTYPE
    { MBase_type MTypeInt }
  | FLOATTYPE
    { MBase_type MTypeFloat }
  | BOOLTYPE
    { MBase_type MTypeBool }
  | CMDTYPE
    { MBase_type MTypeCmd }
  | internal_type = typedecl; LISTTYPE
    { MList_type internal_type }
  | name = modulVar
    {MRef_type name}
  | OPEN_BRACKET; typ = toptypedecl ; CLOSE_BRACKET;
    { typ }
  ;

funargdecl:
  | arg_type=typedecl ; ARROW; args = rev_funarinnergdecl;
    {arg_type :: args }
  ; 

rev_funarinnergdecl:
  | arg_type = typedecl ; 
    {[ arg_type ] }
  | arg_type = typedecl ; ARROW ; args= rev_funarinnergdecl;
    {arg_type :: args }
  ;

typetupelseq :
  | el = typedecl;
    { [el] }
  | el = typedecl; DOUBLE_MINUS; seq = typetupelseq
    { el:: seq }


leaf_expr: 
  | NONE
    {MSimple_val (MNone_val)}
  | i = INT
    {MSimple_val (MBase_val (MTypeIntVal i))}
  | s = STRING 
    {MSimple_val (MBase_val (MTypeStringVal s))}
  | FALSE
    {MSimple_val (MBase_val (MTypeBoolVal false))}
  | TRUE
    {MSimple_val (MBase_val (MTypeBoolVal true))}
  | f = FLOAT
    {MSimple_val (MBase_val (MTypeFloatVal f))}
  | MINUS_OPENING_CHEVRON; set = listSetEl; MINUS_CLOSING_CHEVRON
    {
      MSimple_val (MSet_val set)
    }
  | MINUS_OPENING_CHEVRON;  MINUS_CLOSING_CHEVRON
    {
      MSimple_val (MSet_val [])
    }

  | MINUS_OPENING_CHEVRON; COLON;   MINUS_CLOSING_CHEVRON
    {
      MSimple_val (MMap_val[])
    }
  | MINUS_OPENING_CHEVRON; map = mapEl; MINUS_CLOSING_CHEVRON
    {
      MSimple_val (MMap_val map)
    }
  |  cmdas = cmd_expr;
    { MSimple_val (MBase_val (MTypeCmdVal cmdas)) }
  |  anonf = anonymousfun ; 
    {anonf}

basic_expr:
  | res = leaf_expr 
    { res }
  | LET ; binding_name = var_tuple_decl ; argnames = funargs_top ; AFFECTATION ; binding_value = topvarassign; IN ; OPEN_BRACKET; body = topvarassign ; CLOSE_BRACKET;
    { 
     let open GenUtils in
      MBind_val {mbd_name = binding_name; 
                  mbd_value = 
                    (match argnames with 
                      | [] -> binding_value
                      | lstargs -> MSimple_val (MFun_val (List.rev lstargs, binding_value)))
                  ; 
                  mbd_body =  body;
                  }
    }
  | SOME;  varassign = varassign_in_expr;
    {MSimple_val (MSome_val varassign)}
  | IF ; cond = top_expr ; THEN; thn = top_expr ELSE; els = top_expr; 
  {MIf_val (cond, thn, els)}

  | OPEN_BRACE ;fds = fields_assign; CLOSE_BRACE
    {MComposed_val {mcv_module_def = None; mcv_fields=fds} }
  | md = MODUL;DOT ; OPEN_BRACE ;fds = fields_assign; CLOSE_BRACE
    {let open GenUtils in 
    MComposed_val 
      {mcv_module_def = Some (rm_first_char md); mcv_fields=fds} 
    }
  | comp = comp_expr; 
    {comp}
  |  envvar = ENVVAR; 
     {MEnvRef_val (GenUtils.rm_first_char envvar)}
  |  funcall = modulVar; funargs = funcallargs ; 
     {MRef_val (funcall, funargs)}
  | op = operation ; 
    {op}
  | OPEN_SQRBRACKET ; CLOSE_SQRBRACKET
      {MSimple_val (MList_val [])}
  | OPEN_SQRBRACKET ; lst = listSetEl; CLOSE_SQRBRACKET
    {
      MSimple_val (MList_val lst)
    }
  | OPEN_BRACKET; a = top_expr ;CLOSE_BRACKET;
    {a}
(*
  | OPEN_BRACKET; funcall = modulVar; funargs = funcallargs ;CLOSE_BRACKET; funargs2 = funcallargs
    {MRef_val (funcall, List.append funargs funargs2 )}

*)


(*top_expr is a "toplevel" expresion:
    it can be:
      - a basic expression
      - a tuple expression
      - a sequence of exprsssion
*)
top_expr : 
  | var = basic_expr
    {var}
  | var1 = varassign_in_expr ; DOUBLE_MINUS; seq=in_tuple_assign
    { MSimple_val (MTuple_val  (var1 :: seq)) }

varassign_in_expr : 
  | a = leaf_expr
    {a}
  | OPEN_BRACKET; CLOSE_BRACKET;
    { MSimple_val (MEmpty_val) }
  | OPEN_BRACKET; a = top_expr ; CLOSE_BRACKET;
    {a}
    
  | OPEN_BRACE ;fds = fields_assign; CLOSE_BRACE
    {MComposed_val {mcv_module_def = None; mcv_fields=fds} }
  | md = MODUL;DOT ; OPEN_BRACE ;fds = fields_assign; CLOSE_BRACE
    {let open GenUtils in 
    MComposed_val 
      {mcv_module_def = Some (rm_first_char md); mcv_fields=fds} 
    }
  | OPEN_SQRBRACKET ; CLOSE_SQRBRACKET
      {MSimple_val (MList_val [])}
  | OPEN_SQRBRACKET ; lst = listSetEl; CLOSE_SQRBRACKET
    {
      MSimple_val (MList_val lst)
    }
  | var = modulVar; 
     {MRef_val (var, [])}


comp_expr :
  | expr1 = varassign_in_expr ; EQUALITY; expr2 = varassign_in_expr
    {MComp_val (Egal, expr1, expr2) }
  | expr1 = varassign_in_expr ; INEQUALITY; expr2 = varassign_in_expr
    {MComp_val (NotEqual, expr1, expr2) }
  | expr1 = varassign_in_expr ; CLOSING_CHEVRON ; expr2 = varassign_in_expr
    {MComp_val (GreaterThan, expr1, expr2) }
  | expr1 = varassign_in_expr ; EQ_CLOSING_CHEVRON; expr2 = varassign_in_expr
    {MComp_val (GreaterOrEq, expr1, expr2) }
  | expr1 = varassign_in_expr ; OPENING_CHEVRON ; expr2 = varassign_in_expr
    {MComp_val (LessThan, expr1, expr2) }
  | expr1 = varassign_in_expr ; EQ_OPENING_CHEVRON; expr2 = varassign_in_expr
    {MComp_val (LessOrEq, expr1, expr2) }

anonymousfun: 
  | OPEN_BRACKET; FUN; args = funargs_top; ARROW;   body =topvarassign; CLOSE_BRACKET; 
    { 
    MSimple_val (MFun_val (List.rev args, body))
    }



topvarassign : 
  | assign = top_expr
    { assign }


operation : 
  | OPEN_BRACKET; CLOSE_BRACKET;
    { MSimple_val (MEmpty_val) }
  | i1 = top_expr; PLUS_STR; i2 = top_expr
    {MBasicFunBody_val (MConcatenation, [i1; i2])}
  | i1 = top_expr; PLUS; i2 = top_expr
    {MBasicFunBody_val (MAddition, [i1; i2])}
  | i1 = top_expr; PLUS_DOT; i2 = top_expr 
    {MBasicFunBody_val (MAdditionFloat, [i1; i2])}
  | i1 = top_expr ; MINUS ; i2 = top_expr
    {MBasicFunBody_val (MSoustraction, [i1; i2])}
  | i1 = top_expr ; MINUS_DOT ; i2 = top_expr
    {MBasicFunBody_val (MSoustractionFloat, [i1; i2])}
  | i1 = top_expr ; STAR ; i2 = top_expr
    {MBasicFunBody_val (MMultiplication, [i1; i2])}
  | i1 = top_expr ; STAR_DOT ; i2 = top_expr
    {MBasicFunBody_val (MMultiplicationFLoat, [i1; i2])}
  | i1 = top_expr ; DIVISION ; i2 = top_expr
    {MBasicFunBody_val (MDivision , [i1; i2])}
  | i1 = top_expr ; DIVISION_DOT ; i2 = top_expr
    {MBasicFunBody_val (MDivisionFloat , [i1; i2])}
  | i1 = top_expr; MODULO ; i2 = top_expr
    {MBasicFunBody_val (MModulo, [i1; i2])}
  | i1 = top_expr; MODULO_DOT ; i2 = top_expr
    {MBasicFunBody_val (MModuloFloat, [i1; i2])}
  | i1 = top_expr; WITH ; i2 = top_expr
    {MBasicFunBody_val (MWithList, [i1; i2])}
  | i1 = top_expr; WITH_SET ; i2 = top_expr
    {MBasicFunBody_val (MWithSet, [i1; i2])}
  | i1 = top_expr; WITH_MAP ; i2 = top_expr
    {MBasicFunBody_val (MWithMap, [i1; i2])}
  | i1 = top_expr; WITHOUT_SET ; i2 = top_expr
    {MBasicFunBody_val (MWithoutSet, [i1; i2])}
  | i1 = top_expr; WITHOUT_MAP ; i2 = top_expr
    {MBasicFunBody_val (MWithoutMap, [i1; i2])}
  | i1 = top_expr; SHAS ; i2 = top_expr
    {MBasicFunBody_val (MHasSet, [i1; i2])}
  | i1 = top_expr; MHAS ; i2 = top_expr
    {MBasicFunBody_val (MHasMap, [i1; i2])}
  | assign1 = top_expr; DOUBLE_SEMICOLON ;assign2 = exprseqeassign; 
    { MBody_val (assign1 ::assign2)}

cmd_expr:
  |  cmdas = simple_cmd;
    { cmdas }
  | acmds = cmd_expr ; SIMPLE_AND 
    {
      (ForkedCmd (acmds))
    }
  | acmds = cmd_expr; AND ; bcmds = cmd_expr
    {
      (AndCmd (acmds, bcmds))
    }
  | acmds = cmd_expr; OR ; bcmds = cmd_expr
    {
      (OrCmd (acmds, bcmds))
    }
  | acmds = cmd_expr; PIPE ; bcmds = cmd_expr
    {
      (PipedCmd(acmds, bcmds))
    }
  | acmds = cmd_expr ; SEMICOLON; bcmds = cmd_expr
    {
      (SequenceCmd(acmds, bcmds))
    }



funcallargs :
  | {[]}
  | funarg = varassign_in_expr; funargs = funcallargs
    { funarg :: funargs }


funargs_top:
  |  { [] }
  | varname = VARNAME; funargs = funargs_top;
    { 
      let open GenUtils in 
      (MBaseArg (rm_first_char varname)) ::funargs }
  | OPEN_BRACKET ; subargs = funargs; CLOSE_BRACKET; funargs = funargs_top
    { (MTupleArg subargs) ::funargs }

funargs:
  | arg = VARNAME
    { 
      let open GenUtils in 
      [MBaseArg (rm_first_char arg)] }
  |  OPEN_BRACKET; arg = funargs ; CLOSE_BRACKET;
    { 
      [MTupleArg arg] }
  | arg = VARNAME ; DOUBLE_MINUS ; funargs = funargs
    { 
      let open GenUtils in 
      (MBaseArg (rm_first_char arg)):: funargs }
  | OPEN_BRACKET arg = funargs; CLOSE_BRACKET; DOUBLE_MINUS ; funargs = funargs
    { 
      (MTupleArg arg):: funargs }

exprseqeassign:
  | var1 =varassign_in_expr
    {[var1]}
  | var1 = tupleassign; DOUBLE_SEMICOLON ; seq=exprseqeassign
    {var1 :: seq}

tupleassign:
  | var1 =varassign_in_expr
    {var1}

in_tuple_assign:
  | var1 =varassign_in_expr
    {[var1]}
  | var1 = varassign_in_expr; DOUBLE_MINUS; seq=in_tuple_assign
    {var1 :: seq}

(******* CMD PARSING ********)


simple_cmd:
  | str_cmd = WORD; args = cmd_args; redirs = redirs; 
  | str_cmd = FILE; args = cmd_args; redirs = redirs; 
    {
      let stdout,stdouterr, stdin = List.fold_left 
        (fun (stdout, stdouterr, stdin) redir -> 
          match redir with 
            | MRedirOFile file -> MCMDOFile file, stdouterr, stdin
            | MRedirOFileAppend file -> MCMDOFileAppend file, stdouterr, stdin
            | MRedirEFile file -> stdout, MCMDEFile file, stdin
            | MRedirEFileAppend file -> stdout, MCMDEFileAppend file, stdin
            | MRedirEStdOut -> stdout, MCMDEStdOut, stdin
            | MRedirIFile file -> stdout, stdouterr, MCMDIFile file
            | _ -> assert false

        ) 
        (MCMDOStdOut, 
         MCMDEStdErr, 
         MCMDIStdIn)
        redirs
      in
      let cmd = {mcm_cmd = str_cmd;
                mcm_args = args; 
                mcm_output = stdout; 
                mcm_outputerr = stdouterr; 
                mcm_input_src = stdin; 
               }
    in
     SimpleCmd cmd
    }

cmd_args :
  | arg = cmd_arg; args = cmd_args ; 
    {arg :: args}
  | {[]}


cmd_arg :
  | arg = INT
    {GufoParsed.SORString  (string_of_int arg) }
  | arg = FLOAT
    {GufoParsed.SORString (string_of_float arg) }
  | TRUE 
    {GufoParsed.SORString "true" }
  | FALSE 
    {GufoParsed.SORString "false" }
  | arg = STRING
  | arg = WORD 
  | arg = ARG
  | arg = FILE
    { GufoParsed.SORString arg}
  | TILDE
    {GufoParsed.SORString "~" }
  | DOT
    {GufoParsed.SORString "." }
  | arg = modulVarOrExpr
    { GufoParsed.SORExpr arg}
(** Commenting the STAR and DOT here will solve the states conflicts of * and .
but will make commands such as ls * to fail. *)
  | STAR
    {GufoParsed.SORString "*" }
  | DOT
    {GufoParsed.SORString "." }

redirs :
  | {[]}
  | redir = redir; redirs = redirs;  
    { List.concat [redir; redirs] }


redir : 
  | CLOSING_CHEVRON; file = WORD;
  | CLOSING_CHEVRON; file = FILE;
    { [GufoParsed.MRedirOFile (GufoParsed.SORString file)] }
  | CLOSING_CHEVRON; file = modulVarOrExpr;
    { [GufoParsed.MRedirOFile (GufoParsed.SORExpr file)] }
  | DOUBLE_CLOSING_CHEVRON; file = WORD
  | DOUBLE_CLOSING_CHEVRON; file = FILE
    { [GufoParsed.MRedirOFileAppend (GufoParsed.SORString file)] }
  | DOUBLE_CLOSING_CHEVRON; file = modulVarOrExpr
    { [GufoParsed.MRedirOFileAppend (GufoParsed.SORExpr file)] }
  | WRITE_ERROR_TO; file = WORD
  | WRITE_ERROR_TO; file = FILE
    { [GufoParsed.MRedirEFile (GufoParsed.SORString file)] }
  | WRITE_ERROR_TO; file = modulVarOrExpr
    { [GufoParsed.MRedirEFile (GufoParsed.SORExpr file)] }
  | WRITE_ERROR_NEXT_TO; file = WORD
  | WRITE_ERROR_NEXT_TO; file = FILE
    { [GufoParsed.MRedirEFileAppend (GufoParsed.SORString file)] }
  | WRITE_ERROR_NEXT_TO; file = modulVarOrExpr
    { [GufoParsed.MRedirEFileAppend (GufoParsed.SORExpr file)] }
  | WRITE_ERROR_TO_STD
    { [GufoParsed.MRedirEStdOut] }
  | WRITE_ALL_TO ; file  = WORD
  | WRITE_ALL_TO ; file  = FILE
    { [GufoParsed.MRedirOFile (GufoParsed.SORString file); GufoParsed.MRedirEFile (GufoParsed.SORString file)] }
  | WRITE_ALL_TO ; file  = modulVarOrExpr
    { [GufoParsed.MRedirOFile (GufoParsed.SORExpr file); GufoParsed.MRedirEFile (GufoParsed.SORExpr file)] }
  | OPENING_CHEVRON; file = WORD
  | OPENING_CHEVRON; file = FILE
    { [GufoParsed.MRedirIFile (GufoParsed.SORString file)] }
  | OPENING_CHEVRON; file = modulVarOrExpr
    { [GufoParsed.MRedirIFile (GufoParsed.SORExpr file)] }

(******* CMD PARSING END ********)
(******* FIELDS PARSING ********)

fields_assign:
  | { [] }
  | fields = fields_assign ; fieldname = WORD ; AFFECTATION; value=  topvarassign; COMMA
    { {mtfv_name = fieldname; mtfv_val = value} :: fields }
  ;


modulVar:
  | var = VARNAME; idx = lst_index; 
    {
      let open GenUtils in 
      {mrv_module = None; mrv_varname= [(rm_first_char var)]; mrv_index = idx}}
  |  varfield = VARFIELD; idx = lst_index; 
    {
     let open GenUtils in 
     let lst = Str.split (Str.regexp "\\.") (rm_first_char varfield)  in
    {mrv_module = None; mrv_varname= lst ; mrv_index = idx}
    }
  | var = MODULVAR; idx = lst_index; 
    {
    let open GenUtils in 
    let lst = Str.split (Str.regexp "\\.") (rm_first_char var) in
    let (modul, lst) = (List.hd lst, List.tl lst) in
      {mrv_module = Some modul; mrv_varname= lst ; mrv_index = idx}
    }

lst_index:
  | {None}
  | prev_idx = lst_index; OPEN_SQRIDXBRACKET;elkey = top_expr; CLOSE_SQRBRACKET;
    {match prev_idx with
      | None -> Some [elkey]
      | Some lst -> Some (elkey::lst)
    }



listSetEl:
  | el = top_expr;
    {[el]}
  | el = top_expr; COMMA; lst = listSetEl;
    {el::lst}

mapEl:
  | key = top_expr; COLON ; el = top_expr;
    {[key, el]}
      | key = top_expr; COLON ; el = top_expr; COMMA; lst = mapEl;
    {(key,el)::lst}



modulVarOrExpr:
  | a = ENVVAR
    {MEnvRef_val (GenUtils.rm_first_char a)}
  | a = modulVar
    {MRef_val (a,[])}
  | OPEN_BRACKET ; varassign = top_expr; CLOSE_BRACKET;
    { varassign }


(**
 ##################### END MAIN LANGUAGE PARSER #####################
*)



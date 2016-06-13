grammar edu:umn:cs:melt:exts:ableC:closure:abstractsyntax;

imports silver:langutil;
imports silver:langutil:pp with implode as ppImplode ;

imports edu:umn:cs:melt:ableC:abstractsyntax;
imports edu:umn:cs:melt:ableC:abstractsyntax:construction;
imports edu:umn:cs:melt:ableC:abstractsyntax:env;
imports edu:umn:cs:melt:ableC:abstractsyntax:overload;
--imports edu:umn:cs:melt:ableC:abstractsyntax:debug;

imports edu:umn:cs:melt:exts:ableC:gc;

import silver:util:raw:treemap as tm;

abstract production lambdaExpr
e::Expr ::= captured::EnvNameList params::Parameters res::Expr
{
  e.pp = pp"lambda {${captured.pp}} (${ppImplode(text(", "), params.pps)}) . (${res.pp})";

  local localErrors::[Message] =
    (if !null(lookupValue("_closure", e.env)) then []
     else [err(e.location, "Closures require closure.h to be included.")]) ++
    captured.errors ++ params.errors ++ res.errors;
  
  e.typerep = closureType([], params.typereps, res.typerep);
  
  local paramNames::[Name] = map(name(_, location=builtIn()), map(fst, foldr(append, [], map((.valueContribs), params.defs))));
  captured.freeVariablesIn = removeAllBy(nameEq, paramNames, removeDuplicateNames(res.freeVariables));
  
  res.env = addEnv(params.defs, e.env);
  
  res.returnType = just(res.typerep);
  
  local theName::String = "_fn_" ++ toString(genInt()); 
  local fnName::Name = name(theName, location=builtIn());
  
  local fnDecl::FunctionDecl =
    functionDecl(
      [staticStorageClass()],
      [],
      directTypeExpr(res.typerep),
      functionTypeExprWithArgs(
        baseTypeExpr(),
        consParameters(
          parameterDecl(
            [],
            directTypeExpr(builtinType([], voidType())),
            pointerTypeExpr([], pointerTypeExpr([], baseTypeExpr())),
            justName(name("_env", location=builtIn())),
            []),
          params),
        false),
      fnName,
      [],
      nilDecl(),
      foldStmt([
        captured.envCopyOutTrans,
        declStmt(
           variableDecls(
             [],
             [],
             directTypeExpr(res.typerep),
             consDeclarator(
               declarator(
                 name("_result", location=builtIn()),
                 baseTypeExpr(),
                 [],
                 justInitializer(exprInitializer(res))),
               nilDeclarator()))),
        --captured.envCopyInTrans, -- Not needed, as everything is either a const pointer or a const
        returnStmt(
          justExpr(
            declRefExpr(
              name("_result", location=builtIn()),
              location=builtIn())))]));
  
  local globalDecls::[Pair<String Decl>] = [pair(theName, functionDeclaration(fnDecl))];

  local fwrd::Expr =
    stmtExpr(
      foldStmt([
        declStmt(
          variableDecls(
            [],
            [],
            directTypeExpr(builtinType([], voidType())),
            consDeclarator(
              declarator(
                name("_env", location=builtIn()),
                pointerTypeExpr([], pointerTypeExpr([], baseTypeExpr())),
                [],
                justInitializer(
                  exprInitializer(
                    txtExpr(
                      "(void **)GC_malloc(sizeof(void *) * " ++ toString(captured.len) ++ ")", --TODO
                      location=builtIn())))),
              nilDeclarator()))),
        captured.envAllocTrans,
        captured.envCopyInTrans,
        declStmt(
          variableDecls(
            [],
            [],
            typedefTypeExpr(
              [],
              name("_closure", location=builtIn())),
            consDeclarator(
              declarator(
                name("_result", location=builtIn()),
                baseTypeExpr(),
                [],
                justInitializer(
                  exprInitializer(
                    txtExpr(
                      "(_closure)GC_malloc(sizeof(struct _closure_s))", --TODO
                      location=builtIn())))),
              nilDeclarator()))),
        txtStmt("_result->env = _env;"), --TODO
        txtStmt(s"_result->fn = ${theName};"), -- TODO
        txtStmt(s"_result->fn_name = \"${theName}\";")]), --TODO
      declRefExpr(
        name("_result", location=builtIn()),
        location=builtIn()),
      location=builtIn());
  
  forwards to mkErrorCheck(localErrors, injectGlobalDecls(globalDecls, fwrd, location=e.location));
}

nonterminal EnvNameList with env, pp, errors;

synthesized attribute envAllocTrans::Stmt occurs on EnvNameList;   -- gc mallocs env slots
synthesized attribute envCopyInTrans::Stmt occurs on EnvNameList;  -- Copys env vars into _env
synthesized attribute envCopyOutTrans::Stmt occurs on EnvNameList; -- Copys _env out to vars

synthesized attribute len::Integer occurs on EnvNameList; -- Also used for indexing

inherited attribute freeVariablesIn::[Name] occurs on EnvNameList;

abstract production consEnvNameList
top::EnvNameList ::= n::Name rest::EnvNameList
{
  top.pp =
    case rest of
      nilEnvNameList() -> pp"${n.pp}"
    | _ -> pp"${n.pp}, ${rest.pp}"
    end;
  
  top.errors := n.valueLookupCheck ++ rest.errors;
  top.errors <-
    if skipDef
    then if isNestedFunction
         then [wrn(n.location, n.name ++ " cannot be captured: Cannot capture a nested function")]
         else [wrn(n.location, n.name ++ " cannot be captured")]
    else [];
  
  -- If true, then don't generate load/store code for this variable
  local skip::Boolean = 
    case n.valueItem.typerep of
      functionType(_, _) -> true
    | noncanonicalType(_) -> false -- TODO
    | tagType(_, refIdTagType(_, sName, _)) -> null(lookupRefId(sName, top.env))
    | pointerType(_, functionType(_, _)) -> true -- Temporary hack until pp for function pointer variable defs is fixed
    | _ -> false
    end || n.name == "_env";
    
  -- If true, then don't capture this variable, even if though it is in the capture list
  local skipDef::Boolean = 
    case n.valueItem.typerep of
      functionType(_, _) -> isNestedFunction
    | noncanonicalType(_) -> false -- TODO
    | tagType(_, refIdTagType(_, sName, _)) -> null(lookupRefId(sName, top.env))
    | pointerType(_, functionType(_, _)) -> true -- Temporary hack until pp for function pointer variable defs is fixed
    | _ -> false
    end || n.name == "_env";

  local varBaseType::Type =
    if !null(n.valueLookupCheck)
    then errorType()
    else case n.valueItem.typerep of
           arrayType(t, _, _, _) -> pointerType([], t) -- Arrays get turned into pointers
         | t -> t
         end;
        
  local varBaseTypeExpr::BaseTypeExpr =
    if !null(n.valueLookupCheck)
    then errorTypeExpr(n.valueLookupCheck)
    else directTypeExpr(varBaseType);
    
  local isFunction::Boolean =
    case n.valueItem.typerep of
      functionType(_, _) -> true
    | _ -> false
    end;
    
  {-
  local isFunctionWithBody::Boolean =
    case n.valueItem of
      functionValueItem(functionDecl(_, _, _, _, _, _, _, _)) -> true
    | _ -> false
    end;-}
    
  local isNestedFunction::Boolean =
    case n.valueItem of
      functionValueItem(nestedFunctionDecl(_, _, _, _, _, _, _, _)) -> true
    | _ -> false
    end;
  
  local envAccess::Expr =
    unaryOpExpr(
      dereferenceOp(location=builtIn()),
      explicitCastExpr(
        typeName(
          varBaseTypeExpr,
          pointerTypeExpr(
            [],
            baseTypeExpr())),
        arraySubscriptExpr(
          declRefExpr(
            name("_env", location=builtIn()),
            location=builtIn()),
          realConstant(
            integerConstant(
              toString(rest.len),
              false,
              noIntSuffix(),
              location=builtIn()),
            location=builtIn()),
          location=builtIn()),
        location=builtIn()),
      location=builtIn());

  local varDecl::Declarator =
    declarator(
      n,
      baseTypeExpr(),
      [],
      justInitializer(exprInitializer(envAccess)));
  
  top.envAllocTrans =
    if skip then rest.envAllocTrans else
      seqStmt(
        rest.envAllocTrans,
        txtStmt("_env[" ++ toString(rest.len) ++ "] = (void *)GC_malloc(sizeof(void *));")); -- TODO
  
  top.envCopyInTrans =
    if skip then rest.envCopyInTrans else
      seqStmt(
        rest.envCopyInTrans,
        exprStmt(
          binaryOpExpr(
            envAccess,
            assignOp(
              eqOp(location=builtIn()),
              location=builtIn()),
            declRefExpr(n, location=builtIn()),
          location=builtIn())));
  
  top.envCopyOutTrans =
    if skip then rest.envCopyOutTrans else
      seqStmt(
        rest.envCopyOutTrans,
        declStmt(variableDecls([], [], varBaseTypeExpr, consDeclarator(varDecl, nilDeclarator()))));
  
  top.len = if skip then rest.len else rest.len + 1;
      
  rest.freeVariablesIn = error("freeVariablesIn demanded by tail of capture list");
}

abstract production nilEnvNameList
top::EnvNameList ::=
{
  top.pp = pp"";
  top.errors := [];
  
  top.envCopyInTrans = nullStmt();
  top.envAllocTrans = nullStmt();
  top.envCopyOutTrans = nullStmt();
  top.len = 0;
}

abstract production exprFreeVariables
top::EnvNameList ::=
{
  top.pp = pp"free_variables";
  --top.errors := []; -- Ignore warnings about variables being excluded
  
  local contents::[Name] = removeDuplicateNames(top.freeVariablesIn);
  
  forwards to foldr(consEnvNameList, nilEnvNameList(), contents);
}

function isItemTypedef
Boolean ::= i::Pair<String ValueItem>
{
  return i.snd.isItemTypedef;
}

function isNotItemTypedef
Boolean ::= i::Pair<String ValueItem>
{
  return !i.snd.isItemTypedef;
}

{-
 - New location for expressions which don't have real locations
 -}
abstract production builtIn
top::Location ::=
{
  forwards to loc("Built In", 0, 0, 0, 0, 0, 0);
}

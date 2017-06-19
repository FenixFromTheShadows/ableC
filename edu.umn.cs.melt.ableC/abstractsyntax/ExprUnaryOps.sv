
nonterminal UnaryOp with location, op, opName, pp, host<UnaryOp>, lifted<UnaryOp>, preExpr, noLvalueConversion, typerep, errors, collectedTypeQualifiers;
flowtype collectedTypeQualifiers {op} on UnaryOp;
flowtype errors {op} on UnaryOp;

autocopy attribute op :: Decorated Expr;
synthesized attribute opName :: String;
synthesized attribute preExpr :: Boolean;
synthesized attribute noLvalueConversion :: Boolean;
synthesized attribute collectedTypeQualifiers :: [Qualifier] with ++;

aspect default production
top::UnaryOp ::=
{
  top.opName =
    case top.pp of
      text(opName) -> opName
    | _ -> error("Op pp isn't simple text, opName must be overridden manually")
    end;
}

abstract production preIncOp
top::UnaryOp ::=
{
  top.opName = "pre++";
  propagate host, lifted;
  top.pp = text("++");
  top.preExpr = true;
  top.noLvalueConversion = false;
  top.typerep = top.op.typerep.defaultLvalueConversion.integerPromotions;
  top.collectedTypeQualifiers := [];
  top.errors := [];
}
abstract production preDecOp
top::UnaryOp ::= 
{
  top.opName = "pre--";
  propagate host, lifted;
  top.pp = text("--");
  top.preExpr = true;
  top.noLvalueConversion = true;
  top.typerep = top.op.typerep.integerPromotions;
  top.collectedTypeQualifiers := [];
  top.errors := [];
}
abstract production postIncOp
top::UnaryOp ::= 
{
  top.opName = "post++";
  propagate host, lifted;
  top.pp = text("++");
  top.preExpr = false;
  top.noLvalueConversion = true;
  top.typerep = top.op.typerep.integerPromotions;
  top.collectedTypeQualifiers := [];
  top.errors := [];
}
abstract production postDecOp
top::UnaryOp ::= 
{
  top.opName = "post--";
  propagate host, lifted;
  top.pp = text("--");
  top.preExpr = false;
  top.noLvalueConversion = true;
  top.typerep = top.op.typerep.integerPromotions;
  top.collectedTypeQualifiers := [];
  top.errors := [];
}
abstract production addressOfOp
top::UnaryOp ::=
{
  propagate host, lifted;
  top.pp = text("&");
  top.preExpr = true;
  top.noLvalueConversion = true;
  top.typerep = pointerType(foldQualifier(top.collectedTypeQualifiers), top.op.typerep);
  top.collectedTypeQualifiers := [];
  top.errors := [];
}
--abstract production dereferenceOp
--top::UnaryOp ::=
--{
--  propagate host, lifted;
--  top.pp = text("*");
--  top.preExpr = true;
--  top.noLvalueConversion = false;
--  top.typerep = 
--    case top.op.typerep of
--    | pointerType(_, innerty) -> innerty
--    | _ -> errorType()
--    end;
--  top.errors :=
--    case top.op.typerep.defaultFunctionArrayLvalueConversion of
--    | pointerType(_, _) -> []
--    | _ -> [err(top.location, "invalid type argument of unary ‘*’ (have ‘" ++
--                               showType(top.op.typerep) ++ "’")]
--    end;
--  top.collectedTypeQualifiers := [];
--}
abstract production positiveOp
top::UnaryOp ::=
{
  propagate host, lifted;
  top.pp = text("+");
  top.preExpr = true;
  top.noLvalueConversion = false;
  top.typerep = top.op.typerep.defaultLvalueConversion.integerPromotions;
  top.collectedTypeQualifiers := [];
  top.errors := [];
}
abstract production negativeOp
top::UnaryOp ::=
{
  propagate host, lifted;
  top.pp = text("-");
  top.preExpr = true;
  top.noLvalueConversion = false;
  top.typerep = top.op.typerep.defaultLvalueConversion.integerPromotions;
  top.collectedTypeQualifiers := [];
  top.errors := [];
}
abstract production bitNegateOp
top::UnaryOp ::=
{
  propagate host, lifted;
  top.pp = text("~");
  top.preExpr = true;
  top.noLvalueConversion = false;
  top.typerep = top.op.typerep.defaultLvalueConversion.integerPromotions;
  top.collectedTypeQualifiers := [];
  top.errors := [];
}
abstract production notOp
top::UnaryOp ::=
{
  propagate host, lifted;
  top.pp = text("!");
  top.preExpr = true;
  top.noLvalueConversion = false;
  top.typerep = top.op.typerep.defaultLvalueConversion.integerPromotions;
  top.collectedTypeQualifiers := [];
  top.errors := [];
}

abstract production warnNoOp
top::UnaryOp ::= msg::[Message]
{
  propagate host, lifted;
  top.pp = text("");
  top.preExpr = true;
  top.noLvalueConversion = false;
  top.typerep = top.op.typerep.defaultLvalueConversion.integerPromotions;
  top.collectedTypeQualifiers := [];
  top.errors := [];
}

-- GCC extension
abstract production realOp
top::UnaryOp ::=
{
  propagate host, lifted;
  top.pp = text("__real__");
  top.preExpr = true;
  top.noLvalueConversion = false;
  top.typerep = top.op.typerep.defaultLvalueConversion.integerPromotions;
  top.collectedTypeQualifiers := [];
  top.errors := [];
}
-- GCC extension
abstract production imagOp
top::UnaryOp ::=
{
  propagate host, lifted;
  top.pp = text("__imag__");
  top.preExpr = true;
  top.noLvalueConversion = false;
  top.typerep = top.op.typerep.defaultLvalueConversion.integerPromotions;
  top.collectedTypeQualifiers := [];
  top.errors := [];
}

autocopy attribute typeop :: Type;

nonterminal UnaryTypeOp with location, typeop, pp, host<UnaryTypeOp>, lifted<UnaryTypeOp>, errors;

abstract production sizeofOp
top::UnaryTypeOp ::=
{
  propagate host, lifted;
  top.pp = text("sizeof");
  top.errors := [];
}

-- C11
abstract production alignofOp
top::UnaryTypeOp ::=
{
  propagate host, lifted;
  top.pp = text("_Alignof");
  top.errors := [];
}


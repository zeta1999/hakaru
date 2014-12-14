# Haskell -- this is a "to Haskell" 'printing' module.
#
# A single export
# This prints our AST representation of linear operators

Haskell := module ()
  export ModuleApply;
  local b, p, d, bi,
      parens, resolve, sp, comma, ufunc, bfunc, lbrack, rbrack, seqp,
      lparen, rparen;
  uses StringTools;

  # this is to make things more efficient.  Note that it makes
  # things non-reentrant between Expr and p.
  b := StringBuffer();

  # for the long-term, go right to the 'right' way to do this,
  # which is to use the Inert form.  The flip-side of doing things
  # the right way would involve a proper pretty-printer, but that
  # can be added later easily enough.
  ModuleApply := proc(expr) 
      b:-clear();
      p(ToInert(expr));
      b:-value();
  end;

  p := proc(e)
    if assigned(d[op(0,e)]) then
      d[op(0,e)](op(e))
    else
      error "Haskell: %1 not implemented yet (%2)", op(0,e), e
    end if;
  end;

# things get silly with too much indentation, so for this table, we cheat
d[_Inert_INTPOS] := proc(x) b:-appendf("%d",x) end;
d[_Inert_INTNEG] := proc(x) b:-appendf("(%d)",-x) end;
d[_Inert_RATIONAL] := proc(n,d) 
  parens(proc() p(n); b:-append(" / "); p(d); end) 
end;
d[_Inert_FUNCTION] := proc(f, s)
  local nm;
  nm := resolve(f);
  if assigned(bi[nm]) then
    bi[nm](op(s))
  else
    error "Haskell: cannot resolve function %1", f
  end if;
end proc;
# ignore a2 and subsequent things below
d[_Inert_ASSIGNEDNAME] := proc(a1, a2)
  if assigned(bi[a1]) then
    bi[a1]()
  else
    b:-append(a1);
  end if;
end proc;
d[_Inert_NAME] := proc(a1) 
  if assigned(bi[a1]) then
    bi[a1]()
  else
    b:-append(a1);
  end if;
end proc;
# SUM is n-ary
d[_Inert_SUM] := proc()
  lparen(); seqp(" + ", [_passed]); rparen();
end;
# PROD is n-ary
d[_Inert_PROD] := proc()
  lparen(); seqp(" * ", [_passed]); rparen();
end;
d[_Inert_POWER] := proc(a1,a2)
  # should be Int "^" Int
  #        or Real "^^" Int
  #        or Prob "^^" Int
  #        or Real "**" Real
  #        or Prob "`pow_`" Real
  parens(proc() p(a1); b:-append(" ** "); p(a2) end);
end;
d[_Inert_LESSTHAN] := proc(a1, a2)
  lparen(); b:-append("less"); sp(); p(a1); sp(); p(a2); rparen();
end proc;
d[_Inert_LESSEQ] := proc(a1, a2)
  lparen(); b:-append("or_"); sp(); lbrack(); 
     b:-append("less_"); sp(); p(a1); sp(); p(a2); 
     comma();
     b:-append("equal_"); sp(); p(a1); sp(); p(a2); 
     rbrack();
  rparen();
end proc;

# this is the table of known internal functions
bi["Bind_"] := proc(a1, a2) p(a1); b:-append(" `bind_` "); p(a2) end;
bi["Return"] := ufunc("dirac");
bi["Factor"] := ufunc("factor");
bi["unsafeProb"] := ufunc("unsafeProb");
bi["Unit"] := proc() b:-append("unit") end;
bi["Uniform"] := bfunc("uniform ");
bi["Lebesgue"] := proc() b:-append("lebesgue") end;
bi["Pi"] := proc() b:-append("pi_") end;

bi["Bind"] := proc(meas, var, rest)
  local rng;
  p(meas);
  b:-append(" `bind` \\");
  if type(var, specfunc(anything,'_Inert_NAME')) then
    b:-append(op(1,var));
    b:-append(" -> ");
  else 
    ASSERT(type(var, specfunc(anything, '_Inert_EQUATION')));
    rng := FromInert(op(2,var));
    if rng = -infinity .. infinity then
      b:-append(op([1,1],var));
      b:-append(" -> ");
    else
      error "variable range in `bind` not yet handled";
    end if;
  end if;
  p(rest);
end;

bi["Superpose"] := proc() b:-append("superpose"); sp(); 
  lbrack(); seqp(", ", [_passed]); rbrack();
end;

# will always be called in the context of a superpose
bi["WM"] := proc(w, m)
  b:-append("("); p(w); b:-append(","); p(m); b:-append(")");
end;

bi["Pair"] := proc(l, r)
  b:-append("("); p(l); b:-append(","); p(r); b:-append(")");
end;

bi["exp"] := ufunc("exp");
bi["exp_"] := ufunc("exp_");
bi["ln"] := ufunc("log");
bi["cos"] := ufunc("cos");
bi["sin"] := ufunc("sin");

bi["If"] := proc()
  ASSERT(_npassed>0);
  if _npassed = 1 then p(_passed[1])
  elif _npassed = 2 then
    b:-append("if_ ");
    p(_passed[1]);
    sp();
    lparen(); p(_passed[2]); rparen();
    sp();
    b:-append("0");
  else
    b:-append("if_ ");
    p(_passed[1]);
    sp();
    lparen(); p(_passed[2]); rparen();
    sp();
    lparen(); thisproc(_passed[3..-1]); rparen();
  end if;
end;

# utility routines:
# =================

# printing
  sp := proc() b:-append(" ") end;
  comma := proc() b:-append(",") end;
  lbrack := proc() b:-append("[") end;
  rbrack := proc() b:-append("]") end;
  lparen := proc() b:-append("(") end;
  rparen := proc() b:-append(")") end;
  parens := proc(c) b:-append("("); c(); b:-append(")") end;
  ufunc := proc(f) proc(c) parens(proc() b:-append(f); sp(); p(c) end) end; end;
  bfunc := f -> ((x,y) -> parens(proc() b:-append(f); sp(); p(x); sp(); p(y); end));
  seqp := proc(s, l) 
    if nops(l)=0 then error "empty sequence passed where non-empty expected";
    elif nops(l)=1 then p(l[1]) 
    else
      p(l[1]);
      b:-append(s);
      seqp(s, l[2..-1]);
    end if;
  end proc;

# resolve name
  resolve := proc(inrt)
    local s, nm;
    nm := eval(inrt, _Inert_ATTRIBUTE=NULL); # crude but effective
    if typematch(nm, specfunc('s'::'string', '_Inert_NAME')) then
      s
    elif type(nm, specfunc('string', '_Inert_ASSIGNEDNAME')) then
      op(1,nm)
    else
      error "cannot resolve an %1, namely %2", op(0,nm), nm;
    end if;
  end proc;
end module:

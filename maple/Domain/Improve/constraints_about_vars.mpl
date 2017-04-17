local constraints_about_vars := module()
    export ModuleApply := proc(vs0 :: DomBound, sh :: DomShape, $)
        local vs := vs0, ctx;
        vs  := {op(Domain:-Bound:-varsOf(vs))};
        ctx := Domain:-Bound:-toConstraints(vs0, 'bound_types');
        subsindets(sh, DomConstrain
                  ,x->do_simpl_constraints(vs, ctx, x));
    end proc;

    local do_simpl_constraints := proc(vars, ctx_vs, x, $)
        local ctx1, ctx, ss, td, rest, d, in_vs;
        ss, ctx := selectremove(q->depends(q,indets(vars,And(name,Not(constant)) )), x);
        in_vs := q-> not(lhs(q) in vars) and not(rhs(q) in vars);
        td, rest := selectremove(type, ss, And(relation,satisfies(in_vs)));
        ctx1 := { op(ctx), op(ctx_vs), op(rest) };
        d := map(x->try_make_about(vars,ctx1,x), td);
        DConstrain(op(d), op(ctx), op(rest));
    end proc;

    local try_make_about := proc(vars, ctx1, q0, $)
        local vars_q, q_s, q := q0;
        vars_q := indets(q, name) intersect vars;
        if nops(vars_q) = 1 then
            vars_q := op(1,vars_q);
            q := KB:-try_improve_exp(q, vars_q, ctx1);
            q_s := solve({q},[vars_q], 'useassumptions'=true) assuming (op(ctx1));
            if q_s::list and nops(q_s)=1 then
                op(op(1,q_s));
            else
                q
            end if;
        else
            q
        end if;
    end proc;
end module;

# Pushes constraints down, or pulls them up, when there are such constraints.
local do_ctx_dir := dir -> proc(vs :: DomBound, sh :: DomShape, $)
    local ctx := `if`(nops(vs)=2,op(2,vs),{});
    ctx := remove(x->x::`::`,ctx);
    if ctx <> {} then
        dir(ctx)(sh);
    else
        sh;
    end if;
end proc;

local push_ctx_down :=
  do_ctx_dir(ctx->sh->subsindets(sh, DomConstrain, x->if nops(x)<>0 then DConstrain(op(x), op(ctx)) else DConstrain() end if));

local pull_ctx_out :=
  do_ctx_dir(ctx->sh->subsindets(sh, DomConstrain
            ,x->remove(c->c in ctx or (is(c) assuming ctx), x)));

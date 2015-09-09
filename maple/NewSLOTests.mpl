kernelopts(assertlevel=2): # be strict on all assertions while testing
kernelopts(opaquemodules=false): # allow testing of internal routines
read "NewSLO.mpl":

with(NewSLO):

# covers primitive constructs
model1 := 
  Bind(Gaussian(0,1), x,
  Bind(Msum(Ret(0),Weight(1,Lebesgue())), y,
  Ret(1/exp(x^2+y^2)))):

# simplifies to
model1s :=
  Bind(Gaussian(0,1), x, 
  Msum(Ret(1/exp(x^2)), 
       Bind(Lebesgue(), y, 
       Ret(1/exp(x^2+y^2))))):

CodeTools[Test](value(integrate(model1,z->z)), (sqrt(Pi)+1)/sqrt(3), equal,
  label="primitive constructs + integrate + value");

TestHakaru(model1, model1s, label = "primitive constructs simplification");

# Unknown measures -- no changes
u1 := Bind(m, x, Ret(x^2)):
u2 := Bind(Gaussian(0,1), x, m(x)):

TestHakaru(u1, u1, label = "binding unknown m");
TestHakaru(u2, u2, label = "sending to unknown m");

# example with an elaborate simplifier to do reordering of
# integration, which in turn integrates out a variable
model3 := Bind(Gaussian(0,1),x,Gaussian(x,1)):

TestHakaru(model3, Gaussian(0,sqrt(2)),
 simp = (lo -> evalindets(lo, 'specfunc(Int)',
  i -> evalindets(IntegrationTools[CollapseNested](
                  IntegrationTools[Combine](i)), 'Int(anything,list)',
  i -> subsop(0=int, applyop(ListTools[Reverse], 2, i))))),
  label = "use simplifier to integrate out variable");

# Kalman filter; note the parameter + assumption
kalman := 
  Bind(Gaussian(0,1),x,Weight(NewSLO:-density[Gaussian](x,1)(y),Ret(x))):

TestHakaru( kalman, 
  Weight(exp(-y^2/4)/2/sqrt(Pi),Gaussian(y/2,1/sqrt(2))),
  label = "Kalman filter") assuming y::real;

# piecewise
model4 := 
  Bind(Gaussian(0,1),x,
  Bind(piecewise(x<0,Ret(0),x>4,Ret(4),Ret(x)),y,
  Ret(y^2))):
model4s := Bind(Gaussian(0,1),x,piecewise(x<0,Ret(0),4<x,Ret(16),Ret(x^2))):

TestHakaru(model4, model4s, label = "piecewise test");

# test with uniform.  No change without simplifier, eliminates it with
# call to value.
introLO := 
  Bind(Uniform(0,1),x,
  Bind(Uniform(0,1),y,
  piecewise(x<y,Ret(true),x>=y,Ret(false)))):
introLOs := Msum(Weight(1/2, Ret(false)), Weight(1/2, Ret(true))):

TestHakaru(introLO, introLO, label = "2 uniform - no change");
TestHakaru(introLO, introLOs, simp = value, label = "2 uniform + value = elimination");

# a variety of other tests
TestHakaru(LO(h,(x*applyintegrand(h,5)+applyintegrand(h,3))/x), Weight(1/x, Msum(Weight(x, Ret(5)), Ret(3))));
TestHakaru(Bind(Gaussian(0,1),x,Weight(x,Msum())), Msum());
TestHakaru(Bind(Uniform(0,1),x,Weight(x^alpha,Ret(x))), Weight(1/(1+alpha),BetaD(1+alpha,1)));
TestHakaru(Bind(Uniform(0,1),x,Weight(x^alpha*(1-x)^beta,Ret(x))), Weight(Beta(1+alpha,1+beta),BetaD(1+alpha,1+beta)));
TestHakaru(Bind(Uniform(0,1),x,Weight((1-x)^beta,Ret(x))), Weight(1/(1+beta),BetaD(1,1+beta)));

# tests that basic densities are properly recognized
TestHakaru(Bind(Uniform(0,1),x,Weight(x*2,Ret(x))), BetaD(2,1));
TestHakaru(BetaD(alpha,beta));
TestHakaru(GammaD(a,b));
TestHakaru(LO(h, int(exp(-x/2)*applyintegrand(h,x),x=0..infinity)), Weight(2,GammaD(1,2)));
TestHakaru(LO(h, int(x*exp(-x/2)*applyintegrand(h,x),x=0..infinity)), Weight(4,GammaD(2,2)));
TestHakaru(Bind(Lebesgue(), x, Weight(1/x^2, Ret(x))));
TestHakaru(Cauchy(loc,scale)) assuming scale>0;

# how far does value get us?
TestHakaru(Bind(Uniform(0,1),x,Weight(x,Ret(Unit))), Weight(1/2,Ret(Unit)), simp = value);
TestHakaru(Bind(Weight(1/2,Ret(Unit)),x,Ret(Unit)), Weight(1/2, Ret(Unit)), simp = value);

# and more various
TestHakaru(Bind(Uniform(-1,1),x,Ret(exp(x))));
TestHakaru(IntegrationTools[Expand](LO(h, Int((1+y)*applyintegrand(h,y),y=0..1))), Msum(Uniform(0,1), Weight(1/2,BetaD(2,1))));
TestHakaru(Bind(Uniform(0,1),x,Bind(IntegrationTools[Expand](LO(h, Int((1+y)*applyintegrand(h,y),y=0..1))),y,Ret([x,y]))), Weight(3/2,Bind(Uniform(0,1),x,Msum(Weight(2/3,Bind(Uniform(0,1),y,Ret([x,y]))),Weight(1/3,Bind(BetaD(2,1),y,Ret([x,y])))))));

# and now models (then tests) taken from Tests.RoundTrip
t1 := Bind(Uniform(0, 1), a0, Msum(Weight(a0, Ret(Unit)))):
t2 := BetaD(1,1):
t2s := Bind(Uniform(0, 1), a0, Ret(a0)):
t3 := Gaussian(0,10):
t4 := Bind(BetaD(1, 1), a0, 
      Bind(Msum(Weight(a0, Ret(true)), 
                Weight((1-a0), Ret(false))), a1, 
      Ret(Pair(a0, a1)))):
t4s := Bind(Uniform(0, 1), a0, 
       Msum(Weight(a0, Ret(Pair(a0, true))), 
            Weight((1+(a0*(-1))), Ret(Pair(a0, false))))):
t5 := Bind(Msum(Weight((1/2), Ret(Unit))), a0, Ret(Unit)):
t5s := Weight((1/2), Ret(Unit)):

TestHakaru(t1, t5s, label = "t1");
TestHakaru(t2, t2s, label = "t2");
TestHakaru(t3, t3, label = "t3");
TestHakaru(t4, t4s, label = "t4");
TestHakaru(t5, t5s, label = "t5");

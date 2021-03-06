%
%  Sample EM multi-sphere scattering code
%  
%
%  STEP 1
%
%  First, set solver parameters.
%
%  Set number of terms in multipole expansions 
%      (must be less than or equal to the order of the scattering 
%       matrix generated by the Muller solver). 
%
%  Set itype  (internal parameter, leave set to 1).
%
%  Set nquad  (leave set at nterms    - used internally by Fortran code)
%  Set nphi   (leave set at 2*nquad+1 - used internally by Fortran code)
%  Set ntheta (leave set at nquad+1   - used internally by Fortran code)
%  Set A as below.
%

nterms=12*3;

itype=1;
nquad=nterms;
nphi=2*nquad+1;
ntheta=nquad+1;

A.nterms = nterms;
A.nquad = nquad;
A.nphi = nphi;
A.ntheta = ntheta;

[A.rnodes,A.weights,A.nnodes]=e3fgrid(itype,nquad,nphi,ntheta);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  STEP 2
%
%  Set geometry information 
%
%  Set number of spheres 
%  Set sphere centers in array center
%  Set sphere radii in array radius
%  Set sphere type in array sphere_type 
%      For type=1, the sphere is a perfect conductor.
%      For type=2, the sphere is a dielectric sphere.
%      For type=3, use scattering matrix obtained from Muller solver.
%  Set permeability and permittivity for the inclusions if itype = 2.
%      (ignored for itype = 1,3)
%  Set sphere_rot to change orientation of inclusions if itype = 3.
%  sphere_rot(1:3,i) = [0 0 0] means leave orientation as that from which the 
%                      muller solver computed the scattering matrix 
%  sphere_rot(1:3,i) defines the 3 Euler angles that determine 
%                    an arbitrary orientation.
%  The file rotangles.m contains some typical examples of such rotations.
%  rotangles(2,sphere_rot), used below, rotates all inclusions to be 
%  parallel to the x-axis instead of the z-axis (z -> x, x -> -z, y -> y) or, 
%              equivalently, Euler angles= (0,pi/2,0).
%


nspheres=4;
  
center = zeros(3,nspheres);
center(1:3,1) = [0,0,0];
center(1:3,2) = [0,200,0];
center(1:3,3) = [200,0,0];
center(1:3,4) = [200,200,0];
  
radius = zeros(1,nspheres);
radius(1) = 50;
radius(2) = 50;
radius(3) = 50;
radius(4) = 50;

%%%[nspheres,center,radius]=demo_geometry(4);

sphere_type = zeros(1,nspheres);
for i=1:nspheres
  sphere_type(1,i) = 3;
end
  
%
% If sphere_type equals 2, set eps and mu for each dielectric sphere.
%
sphere_eps = zeros(1,nspheres)+1i*zeros(1,nspheres);
sphere_cmu = zeros(1,nspheres)+1i*zeros(1,nspheres);
  
for i=1:nspheres
  sphere_eps(1,i) = 1;
  sphere_cmu(1,i) = 1;
end
%
%
%  Change orientation of inclusions, if desired.
%
  
sphere_rot = zeros(3,nspheres);
for i=1:nspheres
    sphere_rot(1:3,i)=[0,0,0];
end

sphere_rot=rotangles(2,sphere_rot);

fprintf('nspheres = %d\n',nspheres)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  STEP 3. Read in wavelength data from gold_jc_data and initiallize
%          output arrays for scattering absorption, extinction as well as
%          electric and magnetic dipole moments.
%         

gold_jc_data;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  STEP 4. Run solver (using gold_jc_data points) for a single frequency
%

ifreq = 50;

wavelength=gold_jc(ifreq,2)
omega=2*pi/wavelength

epsE=1;
cmuE=1;
rkE=omega*sqrt(epsE)*sqrt(cmuE);

eps0=1.2;
cmu0=1;
rk0=omega*sqrt(eps0)*sqrt(cmu0);

center0=[0,0,0]';
radius0=200;

ntermsE=ceil(abs(radius0*rkE)*1.2)+24*3
nterms0=ceil(abs(radius0*rk0)*1.2)+24*3

ima=1i;

nspheres=1;
  
center = zeros(3,nspheres);
center(1:3,1) = [0,0,0]';
center(1:3,2) = [0,200,0]';
center(1:3,3) = [200,0,0]';
center(1:3,4) = [200,200,0]';
  
radius = zeros(1,nspheres);
radius(1) = 50;
radius(2) = 50;
radius(3) = 50;
radius(4) = 50;

sphere_type = zeros(1,nspheres);
for i=1:nspheres
  sphere_type(1,i) = 2;
end

re_n=gold_jc(ifreq,3);
im_n=gold_jc(ifreq,4);

for i=1:nspheres
  sphere_eps(1,i) = (re_n+ima*im_n)^2;
  sphere_cmu(1,i) = 1;
end

sphere_rot = zeros(3,nspheres);
for i=1:nspheres
    sphere_rot(1:3,i)=[0,0,0]';
end

%
%  STEP 4: Define the incoming field.

cjvec=[1;0;0];
cmvec=[0;0;0];
source=[0;0;10000];

% construct reflected and transmitted field multipole expansions

% reflected
[aimpoleE,bimpoleE]=em3formta(rkE,source,cjvec,cmvec,center0,ntermsE);

[raE0,rbE0]=rcoefs_die_arb21(ntermsE,omega,radius0,epsE,cmuE,eps0,cmu0);

[raa_diag,rbb_diag]=rmatr_diag(ntermsE,raE0,rbE0);
  atvec = em3sphlin(ntermsE,aimpoleE);
  btvec = em3sphlin(ntermsE,bimpoleE);
  aovec = atvec .* raa_diag;
  bovec = btvec .* rbb_diag;
  aompoleE = em3linsph(ntermsE,aovec);
  bompoleE = em3linsph(ntermsE,bovec);   

% transmitted
[aimpole0,bimpole0]=em3formta(rkE,source,cjvec,cmvec,center0,nterms0);

[taE0,tbE0]=tcoefs_die_arb21(nterms0,omega,radius0,epsE,cmuE,eps0,cmu0);

[taa_diag,tbb_diag]=rmatr_diag(nterms0,taE0,tbE0);
  atvec = em3sphlin(nterms0,aimpole0);
  btvec = em3sphlin(nterms0,bimpole0);
  aovec = atvec .* taa_diag;
  bovec = btvec .* tbb_diag;
  aimpole0 = em3linsph(nterms0,aovec);
  bimpole0 = em3linsph(nterms0,bovec);   


% shift incoming expansions to interior spheres

ncoefs = (nterms+1)*(2*nterms+1);
aimpole = zeros(ncoefs,nspheres);
bimpole = zeros(ncoefs,nspheres);

G=get_e3fgrid(nterms);

for i=1:nspheres

[aimpole(:,i),bimpole(:,i)]=...
      em3tata3(rk0,center0,aimpole0,bimpole0,nterms0, ...
      center(:,i),nterms,radius(i),...
      G.rnodes,G.weights,G.nphi,G.ntheta);

end


%
%  Set up remaining solver parameters
%  omega is frequency, eps0, mu0 are exterior medium parameters.
%

A.omega=omega;
A.epsE=epsE;
A.cmuE=cmuE;
A.rkE=rkE;
A.eps0=eps0;
A.cmu0=cmu0;
A.rk0=rk0;
A.center0=center0;
A.radius0=radius0;
A.ntermsE=ntermsE;
A.nterms0=nterms0;
A.ncoefs0 = (nterms0+1)*(2*nterms0+1);

A.nspheres = nspheres;
A.center = center;
A.radius = radius;
A.type = sphere_type;
A.eps = sphere_eps;
A.cmu = sphere_cmu;
A.rot = sphere_rot;
A.ncoefs = (nterms+1)*(2*nterms+1);

A.iprec=1;



%
%  Construct the right hand side for scattering problem.
%  by applying the scattering/reflection matrix to incoming data.
%
[arhs,brhs]=em3d_multa_r(center,radius,aimpole,bimpole,nterms,A);

%
%  Call the solver em3d_multa_fmps with problem now set up.
%
'FMPS solver for the Maxwell equation in R^3, Matlab + Fortran 90'
tic

rhs = reshape([arhs brhs],A.ncoefs*A.nspheres*2, 1);
sol = gmres_simple(@(x) em3d_multa_fmps_b(A,x), rhs, 1e-12, 20);

sol0 = reshape(sol,A.ncoefs,A.nspheres,2);
aompole = sol0(:,:,1);
bompole = sol0(:,:,2);

time_gmres=toc



%
%  Generate incoming multipole expansions from all 
%  (now known) scattering expansions.
%
[asmpole,bsmpole] = em3d_multa_mptaf90(A.nspheres,A.nterms,A.ncoefs,...
    A.omega,A.eps0,A.cmu0,A.center,A.radius,...
    aompole,bompole,A.rnodes,A.weights,A.nphi,A.ntheta);



% shift outgoing expansions to exterior sphere

ncoefs0 = (nterms0+1)*(2*nterms0+1);
aompole0 = zeros(ncoefs0,1);
bompole0 = zeros(ncoefs0,1);

G0=get_e3fgrid(nterms0);

for i=1:nspheres

[ampoletmp,bmpoletmp]=...
      em3mpmp3(rk0,center(:,i),aompole(:,i),bompole(:,i),nterms, ...
      center0,nterms0,radius0,...
      G0.rnodes,G0.weights,G0.nphi,G0.ntheta);

aompole0 = aompole0+ampoletmp;
bompole0 = bompole0+bmpoletmp;

end


% construct reflected and transmitted field multipole expansions

% reflected
[ra0E,rb0E]=rcoefs_die_arb12(nterms0,omega,radius0,eps0,cmu0,epsE,cmuE);

[raa_diag,rbb_diag]=rmatr_diag(nterms0,ra0E,rb0E);
  atvec = em3sphlin(nterms0,aompole0);
  btvec = em3sphlin(nterms0,bompole0);
  aovec = atvec .* raa_diag;
  bovec = btvec .* rbb_diag;
  aimpole0E = em3linsph(nterms0,aovec);
  bimpole0E = em3linsph(nterms0,bovec);   

% transmitted
[ta0E,tb0E]=tcoefs_die_arb12(nterms0,omega,radius0,eps0,cmu0,epsE,cmuE);

[taa_diag,tbb_diag]=rmatr_diag(nterms0,ta0E,tb0E);
  atvec = em3sphlin(nterms0,aompole0);
  btvec = em3sphlin(nterms0,bompole0);
  aovec = atvec .* taa_diag;
  bovec = btvec .* tbb_diag;
  aompole0E = em3linsph(nterms0,aovec);
  bompole0E = em3linsph(nterms0,bovec);   


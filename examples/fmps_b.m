% Set the path to Matlab scripts and mex files
fmps_init

%
%  Sample EM multi-sphere scattering code
%  
tic
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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

nterms=5;

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
%  STEP 2. Read in wavelength data from gold_jc_data. Define materials
%  constants for exterior and interior media.
%         

gold_jc_data;

ifreq = 50;

wavelength=gold_jc(ifreq,2)
omega=2*pi/wavelength

epsE=1;
cmuE=1;
rkE=omega*sqrt(epsE)*sqrt(cmuE);

eps0=2;
cmu0=1;
rk0=omega*sqrt(eps0)*sqrt(cmu0);

center0=[0,0,0]';
%radius0=2480/4;  % 2 wavelengths
radius0=2480/2;  % 4 wavelengths
%radius0=2480;  % 8 wavelengths
%radius0=2480*4;  % 32 wavelengths
%radius0=2480*8;  % 64 wavelengths



ntermsE=ceil(abs(radius0*rkE)*1.2)+24
nterms0=ceil(abs(radius0*rk0)*1.2)+24

ima=1i;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  STEP 2A
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
center(1:3,1) = [0,0,0]';
center(1:3,2) = [0,200,0]';
center(1:3,3) = [200,0,0]';
center(1:3,4) = [200,200,0]';
  
radius = zeros(1,nspheres);
radius(1) = 50;
radius(2) = 50;
radius(3) = 50;
radius(4) = 50;


[nspheres,center,radius]=fmps_geometry(24);
%nspheres=20;

sphere_type = zeros(1,nspheres);
for i=1:nspheres
  sphere_type(1,i) = 2;
end

re_n=gold_jc(ifreq,3);
im_n=gold_jc(ifreq,4);

%
% If sphere_type equals 2, set eps and mu for each dielectric sphere.
%
for i=1:nspheres
  sphere_eps(1,i) = (re_n+ima*im_n)^2;
  sphere_cmu(1,i) = 1;
end

%
% Change orientation of inclusions, if desired.
%
sphere_rot = zeros(3,nspheres);
for i=1:nspheres
    sphere_rot(1:3,i)=[0,0,0]';
end

%%%sphere_rot=rotangles(2,sphere_rot);

fprintf('nspheres = %d\n',nspheres)


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  STEP 3: Define the incoming field.
%

cjvec=[1;0;0];
cmvec=[0;0;0];
source=[0;0;100000];

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

'after formta', toc
% shift incoming expansions to interior spheres

ncoefs = (nterms+1)*(2*nterms+1);
aimpole = zeros(ncoefs,nspheres);
bimpole = zeros(ncoefs,nspheres);

G=get_e3fgrid(nterms);

for i=1:nspheres

[aimpole(:,i),bimpole(:,i)]=...
      em3tata3_trunc(rk0,center0,aimpole0,bimpole0,nterms0, ...
      center(:,i),nterms,radius(i),...
      G.rnodes,G.weights,G.nphi,G.ntheta);

end
'after tata3', toc
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  STEP 4. Run solver (using gold_jc_data points) for a single frequency
%

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
A.ncoefsE = (ntermsE+1)*(2*ntermsE+1);

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
sol = gmres_simple(@(x) em3d_multa_fmps_b(A,x), rhs, 1e-3, 40);

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


return

%
%  POSTPROCESSING
%
%  evaluate E and H fields at a target grid
%   1 wavelengths below the x-y plane
%

ngrid = 64;

x = linspace(-2100,2100,ngrid);
y = linspace(-2100,2100,ngrid);

evecs = zeros(3,ngrid,ngrid);
hvecs = zeros(3,ngrid,ngrid);

ntargets = ngrid*ngrid;
targets = zeros(3,ngrid,ngrid);
for k=1:ngrid
    for j=1:ngrid
        targets(:,j,k) = [x(j), y(k), -radius0-wavelength]';
    end
end


evecs = reshape(evecs,3,ngrid*ngrid);
hvecs = reshape(hvecs,3,ngrid*ngrid);
targets = reshape(targets,3,ngrid*ngrid);


ncoefs0 = (nterms0+1)*(2*nterms0+1);
ncoefsE = (ntermsE+1)*(2*ntermsE+1);


% scattered field
[evecsE,hvecsE] = em3d_mpole_targeval(1,ntermsE,ncoefsE,...
    omega,epsE,cmuE,center0,radius0,...
    aompoleE,bompoleE,ntargets,targets);

[evecs0E,hvecs0E] = em3d_mpole_targeval(1,nterms0,ncoefs0,...
    omega,epsE,cmuE,center0,radius0,...
    aompole0E,bompole0E,ntargets,targets);

evecs=evecsE+evecs0E;
hvecs=hvecsE+hvecs0E;

[evec0,hvec0] = em3dipole3etimp(rkE,epsE,cmuE,source,targets,cjvec);
evecs=evecs+evec0;
hvecs=hvecs+hvec0;

[evec0,hvec0] = em3dipole3mtimp(rkE,epsE,cmuE,source,targets,cmvec);
evecs=evecs+evec0;
hvecs=hvecs+hvec0;

[evecs,hvecs]=em3dipole3ehimp(rkE,epsE,cmuE,evecs,hvecs);


targets = reshape(targets,3,ngrid,ngrid);
evecs = reshape(evecs,3,ngrid,ngrid);
hvecs = reshape(hvecs,3,ngrid,ngrid);


figure(11)
imagesc(x,y,reshape(real(evecs(1,:,:)),ngrid,ngrid))
colorbar
title('Total field: Re(E_x)')

figure(12)
imagesc(x,y,reshape(imag(evecs(1,:,:)),ngrid,ngrid))
colorbar
title('Total field: Im(E_x)')

%figure(13)
%imagesc(x,y,reshape(angle(evecs(1,:,:)),ngrid,ngrid))
%colorbar
%title('Total field: phase(E_x)')




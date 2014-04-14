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

nterms=6;

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
%  sphere_rot(1:3,i) defines the 3 Euler angles that determine an arbitrary orientation.
%  The file rotangles.m contains some typical examples of such rotations.
%  rotangles(2,sphere_rot), used below, rotates all inclusions to be 
%  parallel to the x-axis instead of the z-axis (z -> x, x -> -z, y -> y) or, 
%              equivalently, Euler angles= (0,pi/2,0).
%

nspheres=1;

center = zeros(3,nspheres);
center(1:3,1) = [0,0,0];
  
radius = zeros(1,nspheres);
radius(1) = 100;

%%%[nspheres,center,radius]=demo_geometry(1);

sphere_type = zeros(1,nspheres);
for i=1:nspheres
  sphere_type(1,i) = 3;
end

%
% If type equals 2, set eps and mu for each dielectric sphere.
%
sphere_eps = zeros(1,nspheres)+1i*zeros(1,nspheres);
sphere_cmu = zeros(1,nspheres)+1i*zeros(1,nspheres);
  
for i=1:nspheres
  sphere_eps(1,i) = 2;
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

%%%sphere_rot=rotangles(1,sphere_rot);
sphere_rot=rotangles(2,sphere_rot);
%%%sphere_rot=rotangles(4,sphere_rot);

fprintf('nspheres = %d\n',nspheres)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  STEP 3. Read in wavelength data from gold_jc_data and initiallize
%          output arrays for scattering absorption, extinction as well as
%          electric and magnetic dipole moments.
%         

gold_jc_data;

qabs_total = zeros(1,120);
qsca_total = zeros(1,120);
qext_total = zeros(1,120);
pdipole = zeros(3,120);
mdipole = zeros(3,120);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  STEP 4. Run frequency scan (using gold_jc_data points)
%

for ifreq = 11:120

wavelength=gold_jc(ifreq,2)
omega=2*pi/wavelength
eps0=1;
cmu0=1;
zk=omega*sqrt(eps0)*sqrt(cmu0);

%%%sphere_eps(1:nspheres) = (gold_jc(ifreq,3)+1i*gold_jc(ifreq,4))^2

%
%  STEP 4A: Define the incoming field.
%  The incoming plane wave is specified by the direction vector (kvec) and
%  the corresponding E polarization vector (epol).
%
kvec = zk*[0 0 -1];
epol = [1 0 0];

%
%  STEP 4B: get incoming E and H fields on all FMPS sphere boundaries
%

nnodes = A.nnodes;
nphi = A.nphi;
ntheta = A.ntheta;

evecs = zeros(3,nnodes,nspheres) + 1i*zeros(3,nnodes,nspheres);
hvecs = zeros(3,nnodes,nspheres) + 1i*zeros(3,nnodes,nspheres);

for j=1:nspheres

ntargets = nphi*ntheta;
targets = repmat(center(:,j),1,nnodes)+A.rnodes*radius(j);

[evecs(:,:,j),hvecs(:,:,j)] = ...
    em3d_planearb_targeval(kvec,epol,ntargets,targets);

end

%
%  STEP 4C: convert incoming E and H fields to local vector 
%           spherical harmonic expansions.
%
ncoefs = (nterms+1)*(2*nterms+1);
aimpole = zeros(ncoefs,nspheres);
bimpole = zeros(ncoefs,nspheres);

for j=1:nspheres

[aimpole(:,j),bimpole(:,j)]=...
   em3ehformta(zk, center(:,j), radius(j), ...
   A.rnodes, A.weights, A.nphi, A.ntheta,  ...
   evecs(:,:,j), hvecs(:,:,j), nterms);

end

%
%  Set up remaining solver parameters
%  omega is frequency, eps0, mu0 are exterior medium parameters.
%

A.omega=omega;
A.eps0=1;
A.cmu0=1;

A.nspheres = nspheres;
A.center = center;
A.radius = radius;
A.type = sphere_type;
A.eps = sphere_eps;
A.cmu = sphere_cmu;
A.rot = sphere_rot;
A.ncoefs = (nterms+1)*(2*nterms+1);

A.iprec = 0;

%
%  Matlab + Fortran 90 solver: Extract relevant scattering matrix from a file in the
%  directory
%
%  ../data/scat.2ellipsoids-25x25x75-sep40-gold-draft
%

%%%scatfile = ['..' filesep 'data' filesep 'scat.2ellipsoids-25x25x75-sep40-gold-draft' filesep 'scat.freq.' num2str(ifreq)]
scatfile = ['data' filesep 'scat.2ellipsoids-25x25x75-sep145-gold-draft' filesep 'scat.freq.' num2str(ifreq)]
%%%copyfile(scatfile,'fort.19');
[A.raa,A.rab,A.rba,A.rbb,A.nterms_r,ier]=rmatr_file(scatfile);

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
sol = gmres_simple(@(x) em3d_multa_fmps(A,x), rhs, 1e-3, 20);

sol0 = reshape(sol,A.ncoefs,A.nspheres,2);
aompole = sol0(:,:,1);
bompole = sol0(:,:,2);

time_gmres=toc

%
%  Generate incoming multipole expansions from all (now known) scattering expansions.
%
[asmpole,bsmpole] = em3d_multa_mptaf90(A.nspheres,A.nterms,A.ncoefs,...
    A.omega,A.eps0,A.cmu0,A.center,A.radius,...
    aompole,bompole,A.rnodes,A.weights,A.nphi,A.ntheta);

%
%  POSTPROCESSING
%
%  Evaluate E and H fields on all spheres
%
eivecs = zeros(3,nnodes,nspheres) + 1i*zeros(3,nnodes,nspheres);
hivecs = zeros(3,nnodes,nspheres) + 1i*zeros(3,nnodes,nspheres);
esvecs = zeros(3,nnodes,nspheres) + 1i*zeros(3,nnodes,nspheres);
hsvecs = zeros(3,nnodes,nspheres) + 1i*zeros(3,nnodes,nspheres);
eovecs = zeros(3,nnodes,nspheres) + 1i*zeros(3,nnodes,nspheres);
hovecs = zeros(3,nnodes,nspheres) + 1i*zeros(3,nnodes,nspheres);

for i=1:nspheres

 [evecs,hvecs]=...
    em3taevaleh(zk,center(:,i),aimpole(:,i),bimpole(:,i),nterms, ...
    center(:,i),radius(i),A.rnodes,A.weights,A.nphi,A.ntheta);
  eivecs(:,:,i) = evecs;
  hivecs(:,:,i) = hvecs;

 [evecs,hvecs]=...
    em3taevaleh(zk,center(:,i),asmpole(:,i),bsmpole(:,i),nterms, ...
    center(:,i),radius(i),A.rnodes,A.weights,A.nphi,A.ntheta);
  esvecs(:,:,i) = evecs;
  hsvecs(:,:,i) = hvecs;

 [evecs,hvecs]=...
    em3mpevaleh(zk,center(:,i),aompole(:,i),bompole(:,i),nterms, ...
    center(:,i),radius(i),A.rnodes,A.weights,A.nphi,A.ntheta);
  eovecs(:,:,i) = evecs;
  hovecs(:,:,i) = hvecs;

end

%
%  Evaluate absorption, scattering, and extinction cross sections
%
 
% total field 
etvecs = eivecs + esvecs + eovecs;
htvecs = hivecs + hsvecs + hovecs;

% scattered field
eavecs = esvecs + eovecs;
havecs = hsvecs + hovecs;

qabs = zeros(1,nspheres) + 1i*zeros(1,nspheres);
qsca = zeros(1,nspheres) + 1i*zeros(1,nspheres);
qext = zeros(1,nspheres) + 1i*zeros(1,nspheres);

for i=1:nspheres
  ptvecs = cross(etvecs(:,:,i),conj(htvecs(:,:,i)));
  qabs(i) = A.weights  * sum(ptvecs .* A.rnodes,1)' / pi;

  pavecs = cross(eavecs(:,:,i),conj(havecs(:,:,i)));
  qsca(i) = A.weights  * sum(pavecs .* A.rnodes,1)' / pi;

  pxvecs = cross(eavecs(:,:,i),conj(hivecs(:,:,i))) ...
    + cross(eivecs(:,:,i),conj(havecs(:,:,i)));
  qext(i) = -A.weights  * sum(pxvecs .* A.rnodes,1)' / pi;
end

qabs;
qsca;
qext;

qabs_total(ifreq) = sum(qabs * pi .* A.radius.^2);
qsca_total(ifreq) = sum(qsca * pi .* A.radius.^2);
qext_total(ifreq) = sum(qext * pi .* A.radius.^2);


%
%  Evaluate total electric and magnetic dipole moments 
%  Works for one sphere only (centered at the origin)
%
pvec_ave = zeros(3,1) + 1i*zeros(3,1);
mvec_ave = zeros(3,1) + 1i*zeros(3,1);
 
for i=1:nspheres

[pvec0,mvec0]=empol(wavelength,zk,aompole(:,i),bompole(:,i),...
		    nterms,radius(i));	
pvec_ave = pvec_ave + pvec0;
mvec_ave = mvec_ave + mvec0;

end

pvec_ave;
mvec_ave;

pdipole(1:3,ifreq) = pvec_ave;
mdipole(1:3,ifreq) = mvec_ave;


end




if( 1 == 2 ),
%
%  POSTPROCESSING
%
%  evaluate E and H fields at a target grid
%   10 wavelengths below the x-y plane
%

ngrid = 4;

x = linspace(-2100,2100,ngrid);
y = linspace(-2100,2100,ngrid);

evecs = zeros(3,ngrid,ngrid);
hvecs = zeros(3,ngrid,ngrid);

ntargets = ngrid*ngrid;
targets = zeros(3,ngrid,ngrid);
for k=1:ngrid
    for j=1:ngrid
        targets(:,j,k) = [x(j), y(k), -wavelength*10]';
    end
end

% scattered field
[evecs,hvecs] = em3d_mpole_targeval(nspheres,nterms,ncoefs,...
    omega,eps0,cmu0,center,radius,...
    aompole,bompole,ntargets,targets);

if ( 1 == 2 ),
% incoming field
kvec = zk*[0 0 -1];
epol = [1 0 0];
[evec0,hvec0] = em3d_planearb_targeval(kvec,epol,ntargets,targets);

% total field
evecs = evecs+evec0;
hvecs = hvecs+hvec0;
end

evecs = reshape(evecs,3,ngrid,ngrid);
hvecs = reshape(hvecs,3,ngrid,ngrid);

evecs5 = evecs;
hvecs5 = hvecs;

end


%
%  convert into SI units
%
eps0=8.8541878e-12
cmu0=4*pi*1e-7
clight=2.99792458e8

pdipole = pdipole*(4*pi*eps0)*1e-27;
mdipole = mdipole*(4*pi/cmu0)*1e-27/clight;

qabs_total = qabs_total * (1e-18/2/376.73);
qsca_total = qsca_total * (1e-18/2/376.73);
qext_total = qext_total * (1e-18/2/376.73);

%
%  plot electric and magnetic polarization vectors
%
figure(1);
x = 11:120;
plot( gold_jc(x,2), real(pdipole(1,x)), gold_jc(x,2), imag(pdipole(1,x)))
title('electric polarization vector (SI)')
grid on

figure(2);
x = 11:120;
plot( gold_jc(x,2), real(mdipole(2,x)), gold_jc(x,2), imag(mdipole(2,x)))
title('magnetic polarization vector (SI)')
grid on

figure(3);
x = 11:120;
plot( gold_jc(x,2), -real(qabs_total(x)), gold_jc(x,2), real(qsca_total(x)))
title('absorption and scattering cross sections (SI)')
grid on




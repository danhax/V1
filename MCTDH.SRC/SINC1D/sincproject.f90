
#include "Definitions.INC"

module myprojectmod
  implicit none

  DATATYPE, allocatable ::  threed_two(:)

  type fourmat
     DATATYPE, allocatable :: mat(:,:,:,:)
  end type fourmat

  type twomat
     real*8, allocatable :: mat(:,:)
  end type twomat

  type onemat
     real*8, allocatable :: rmat(:)
     DATATYPE, allocatable :: cmat(:)
  end type onemat

  type(fourmat) :: ketot,fdtot
  type(twomat) ::  sinepoints
  type(onemat) :: kevect,fdvect

  DATATYPE, allocatable :: dipoles(:),&

!! WAS:  e.g. X(x) = x + i scalefunction(x,1)


       jacobian(:),&         !! jacobian(:,1) should only be a function of x, etc.
       invjacobian(:),&
       invsqrtjacobian(:),&
       scalediag(:),&
       invsqrtscaleweights(:),&
       scaleweights13(:), &
       invscaleweights13(:),&
       scaleweights16(:), &
       invscaleweights16(:)

end module myprojectmod


subroutine myprojectalloc()
  use myparams
  use pmpimod
  use pfileptrmod
  use myprojectmod
  implicit none

  allocate(dipoles(totpoints))
  dipoles=0
  
  if (scalingflag.ne.0) then
     allocate(          jacobian(totpoints),invjacobian(totpoints), &
          invsqrtjacobian(totpoints), &
          scalediag(totpoints),&
          invsqrtscaleweights(totpoints),scaleweights13(totpoints),&
          invscaleweights13(totpoints),scaleweights16(totpoints),&
          invscaleweights16(totpoints))
     jacobian=0; invjacobian=0; invsqrtjacobian=0; scalediag=0;
     invsqrtscaleweights=0;scaleweights13=0;invscaleweights13=0;
     scaleweights16=0;invscaleweights16=0;
  endif

  if (toepflag.eq.0) then
  
     if (numpoints*nbox.gt.10000) then
        OFLWR "WOW THAT'S BIG!  Are you sure you don't want to try toepflag?", numpoints*nbox; CFL
        OFLWR "WOW THAT'S BIG!  Are you sure you don't want to try toepflag?", numpoints*nbox; CFL
        OFLWR "WOW THAT'S BIG!  Are you sure you don't want to try toepflag?", numpoints*nbox; CFL
     endif

!! Allocating extra here for fdtot%mat and ketot%mat (+1's) --
!!   see Z/GEMM calls in coreproject.f90... leading dimension not
!!   allocated as passed to Z/GEMM without extra

     if (orbparflag) then
        allocate( &
             fdtot%mat(numpoints,nbox,numpoints,myrank:myrank +1), &
             ketot%mat(numpoints,nbox,numpoints,myrank:myrank +1))
     else
        allocate( &
             fdtot%mat(numpoints,nbox,numpoints,nbox), &
             ketot%mat(numpoints,nbox,numpoints,nbox))
     endif

     fdtot%mat=0; ketot%mat=0; 
  endif

  allocate( &
       kevect%rmat(0-gridpoints:gridpoints-1),&
       kevect%cmat(0-gridpoints:gridpoints-1),&
       fdvect%rmat(0-gridpoints:gridpoints-1),&
       fdvect%cmat(0-gridpoints:gridpoints-1),&
       sinepoints%mat(numpoints,nbox))

  kevect%rmat=0; kevect%cmat=0;
  fdvect%rmat=0; kevect%cmat=0

  allocate(threed_two(0-numpoints:numpoints-1))
  threed_two=0

end subroutine myprojectalloc


module twoemod
  implicit none
  DATATYPE, allocatable :: frozenreduced(:)
end module twoemod


subroutine get_twoe_new(pot)
  use myparams
  use pfileptrmod
  use myprojectmod  
  use pmpimod
  implicit none
  DATATYPE,intent(out) :: pot(totpoints)
  DATATYPE,allocatable :: myarray(:)
  DATATYPE :: ffunct
  real*8 :: sum,sum2
  integer :: ii,jj,pp,gridoffset,istart,icenter

  istart=1
  if (orbparflag.and.myrank.ne.1) then
     istart=0
  endif
  gridoffset=0; pp=1-gridpoints
  if (orbparflag) then
     gridoffset=(myrank-1)*numpoints
     pp=istart+2*gridoffset-gridpoints
  endif

  allocate(myarray(istart-numpoints:numpoints-1)); myarray=0

  jj=pp
  do ii=istart-numpoints,numpoints-1
     myarray(ii)=jj*spacing
     jj=jj+1
  enddo

  threed_two(:)=0d0

  if (twotype.eq.0) then
     threed_two(istart-numpoints:numpoints-1) = twostrength
  else
     threed_two(istart-numpoints:numpoints-1) = 0.5d0 * sech(myarray(:),2*numpoints-istart)**2 * twostrength
  endif

  deallocate(myarray)

  gridoffset=0
  if (orbparflag) then
     gridoffset=(myrank-1)*numpoints
  endif
  sum=(gridoffset - gridpoints/2d0) * spacing

  allocate(myarray(numpoints)); myarray=0

  if (numcenters.eq.0) then
     pot(:) = 0.5d0 * harmstrength * dipoles(:)**2
  else
!! Add in after get orbs  
     pot(:)=0d0
  endif

  do icenter=1,numcenters

     sum2=sum
     do ii=1,numpoints
        myarray(ii)=ffunct((sum2 - centershift(icenter)*spacing/2d0)/softness(icenter))
        sum2=sum2+spacing
     enddo

     pot(:)=pot(:) - 0.5d0 * nuccharges(icenter)*(nuccharges(icenter)+1) / softness(icenter)**2 * &
          sech(myarray(:),numpoints)**2
  enddo

  deallocate(myarray)

contains
  function sech(inarray,num)
    implicit none
    integer,intent(in) :: num
    DATATYPE,intent(in) :: inarray(num)
    DATATYPE :: sech(num)
    sech(:) = 2d0/(exp(inarray(:)) + exp((-1)*inarray(:)))
  end function sech
    
end subroutine get_twoe_new



subroutine op_yderiv(notint,notused1,notused2)
  use pfileptrmod
  implicit none
  integer :: notint
  DATATYPE :: notused1(*), notused2(*)
  OFLWR "WHAT! no op_yderiv sincdvr, not yet."; CFLST
  notused1(1)=0*notused2(1)
end subroutine op_yderiv

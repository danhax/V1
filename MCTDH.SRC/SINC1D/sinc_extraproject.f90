

!!!  EXTRA COORINATE SPECIFIC ROUTINES INCLUDING DIATOMSTATS FOR EXPECTATION VALUES (DiatomStats.Dat)


#include "Definitions.INC"

!! boxes subroutine getmyparams(inmpifileptr,inpfile,spfdims,outnumsh ells,outdim)

subroutine getmyparams(inmpifileptr,inpfile,spfdims,spfdimtype,reducedpotsize,outnumr,&
     outnucrepulsion,nonuc_checkflag)
  use myparams
  use pfileptrmod
  use pmpimod
  use onedfunmod
  implicit none

  integer,intent(in) :: inmpifileptr
  character,intent(in) :: inpfile*(*)
  integer,intent(out) :: spfdims(3),spfdimtype(3),nonuc_checkflag,reducedpotsize, outnumr
  real*8,intent(out) :: outnucrepulsion
  integer :: nargs, i,j, len,getlen,myiostat
  character (len=SLN) :: buffer
  character (len=SLN) :: nullbuff
!  real*8 :: fac1,fac2
  real*8, parameter :: pi = 3.14159265358979323844d0
  DATATYPE :: csums(1)
  NAMELIST /sinc1dparinp/        numpoints,spacing,twostrength,nuccharges,orblanthresh, &
       numcenters,centershift,orblanorder,nonucrepflag,debugflag, &
       orbparflag,num_skip_orbs,orb_skip,orblancheckmod,zke_paropt,&
       capflag,capstrength,capstart,cappower,fft_ct_paropt,fft_batchdim,&
       fft_circbatchdim,maxcap,mincap,capmode, &
       scalingflag,scalingdistance,smoothness,scalingtheta,scalingstretch,&
       ivoflag, loadedocc, orbtargetflag,orbtarget,&
       toepflag,softness,twotype,harmstrength, twomode, nucstrength, eigmode

#ifdef PGFFLAG
  integer :: myiargc
  nargs=myiargc()
#else
  nargs=iargc()
#endif

  do i=1,SLN
     nullbuff(i:i)=" "
  enddo

!!! MPI INIT

  call getworldcommgroup(PROJ_COMM_WORLD,PROJ_GROUP_WORLD)
  mpifileptr=inmpifileptr
  call getmyranknprocs(myrank,nprocs)

  nonuc_checkflag=1
  outnumr=1

  open(971,file=inpfile, status="old", iostat=myiostat)

  if (myiostat/=0) then
     OFLWR "No Input.Inp found, not reading sincparams. iostat=",myiostat;CFL
  else
     read(971,nml=sinc1dparinp)
     close(971)

!! enforce defaults that depend on other variables

     open(971,file=inpfile, status="old", iostat=myiostat)
     read(971,nml=sinc1dparinp)
     close(971)

  endif

  call openfile()
  do i=1,nargs
     buffer=nullbuff
     call getarg(i,buffer)
     len=getlen(buffer)
     if (buffer(1:2) .eq. 'N=') then
        read(buffer(3:len),*) numpoints
        write(mpifileptr, *) "numpoints set to ", numpoints
     endif
     if (buffer(1:9) .eq. 'Batchdim=') then
        read(buffer(10:len),*) fft_batchdim
        write(mpifileptr, *) "fft_batchdim set to ", fft_batchdim
     endif
     if (buffer(1:10) .eq. 'Circbatch=') then
        read(buffer(11:len),*) fft_circbatchdim
        write(mpifileptr, *) "fft_circbatchdim set to ", fft_circbatchdim
     endif
     if (buffer(1:6) .eq. 'SDebug') then
        if (.not.(buffer(1:7) .eq. 'SDebug=')) then
           write(mpifileptr,*) "Please set SDebug= not SDebug as command line option"; CFLST
        endif
        read(buffer(8:len),*) debugflag
        write(mpifileptr, *) "Debugflag for sinc dvr set to ",debugflag," by command line option"
     endif
  enddo
  call closefile()


  if (myrank.eq.1.and.debugflag.ne.0) then
     call ftset(1,mpifileptr)
  else
     call ftset(0,-99)
  endif

!! matches main
  if (nprocs.eq.1) then
     orbparflag=.false.
  endif

  if (orbparflag) then
     if (mod(numpoints,nprocs).ne.0) then
        OFLWR "ACK, numpoints is not divisible by nprocs",numpoints,nprocs; CFLST
     endif
  endif  

!! NBOX HARDWIRE 1 BUT FOR PAR.

  nbox=1
  qbox=1
  if (orbparflag) then
     numpoints=numpoints/nprocs
     nbox=nprocs
     qbox=myrank
  endif

  totpoints=numpoints

  gridpoints=nbox*numpoints

  spfdims(:)=1
  spfdims(3)=numpoints

  spfdimtype(:)=1   !! [ -inf...inf  variable range ]

  reducedpotsize=numpoints

  sumcharge=0d0
  nucrepulsion=0
  do i=1,numcenters
     sumcharge=sumcharge+nuccharges(i)
!     fac1=getscalefac0(i)
     do j=i+1,numcenters
!        fac2=getscalefac0(j)        
        !! if twotype=0, then constant two-electron and zero internuclear interaction
        if (twotype.ne.0)  then
           csums(:) = &
                onedfun(DATAONE*(centershift(i:i)-centershift(j:j))/2,1,1d0,1d0) / &
                onedfun(DATAZERO*(centershift(i:i)-centershift(j:j))/2,1,1d0,1d0) * &
                (2*(nuccharges(i)+nuccharges(j))**2-nuccharges(i)**2-nuccharges(j)**2)/2d0
           nucrepulsion = nucrepulsion + csums(1) * nucstrength ;
        endif
     end do
  enddo

  outnucrepulsion = nucrepulsion
  
  return
  
end subroutine getmyparams


subroutine printmyopts()
  use myparams
  use pfileptrmod
  implicit none
  integer :: ii

!!no  OFLWR
  WRFL "********  SINC DVR PARAMS ******** " 
  WRFL "spacing",spacing
  WRFL "numpoints",numpoints
  WRFL "********  HAMILTONIAN PARAMS ******** "
  WRFL "numcenters",numcenters
  do ii=1,numcenters
     WRFL "  nuccharge",nuccharges(ii)
     WRFL "  radius   ",centershift(ii)*0.5d0
  enddo
  WRFL "twostrength", twostrength
  WRFL "nucstrength", nucstrength
  if (twotype.eq.0) then
     WRFL "constant two-body interaction, twotype==0"
  else
     WRFL "potential two-body interaction, twotype.ne.0"
     WRFL "  softness", softness
  endif
  if (twomode.eq.0) then
     WRFL "sech^2 potential, twomode==0"
  else
     WRFL "soft coulomb potential, twomode.ne.0"
  endif
  WRFL "********  OTHER PARAMS ********** "
  WRFL "orblanorder,orblanthresh",orblanorder,orblanthresh
  WRFL "nonucrepflag",nonucrepflag
  WRFL "orbparflag",orbparflag
  WRFL "zke_paropt",zke_paropt
  WRFL "   --> fft_ct_paropt",fft_ct_paropt
  WRFL "fft_batchdim",fft_batchdim
  WRFL "fft_circbatchdim",fft_circbatchdim
  WRFL "  -----  "
  WRFL "NBOX ", nbox
  WRFL "totpoints",totpoints
  WRFL "**********************************"
!!no  CFL
  
end subroutine printmyopts

subroutine checkmyopts()
end subroutine checkmyopts



function cylindricalvalue() !radpoint, thetapoint,nullrvalue,mvalue, invector)
  DATATYPE :: cylindricalvalue
  cylindricalvalue=0d0
print *, "DOME CYLINDRICAL VALUE SINC (what?)"; stop
end function cylindricalvalue

subroutine get_maxsparse() !nx,ny,nz,xvals,yvals,zvals, maxsparse,povsparse)
  print *, "DOME get_maxsparse SINC"; STOP
end subroutine get_maxsparse
subroutine get_sphericalsparse() !nx,ny,nz,xvals,yvals,zvals, maxsparse,sparsetransmat,sparsestart,sparseend,sparsexyz,povsparse)
  print *, "DOME get_sphericalsparse SINC"; STOP
end subroutine get_sphericalsparse

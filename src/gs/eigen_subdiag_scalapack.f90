!
!  Copyright 2019 SALMON developers
!
!  Licensed under the Apache License, Version 2.0 (the "License");
!  you may not use this file except in compliance with the License.
!  You may obtain a copy of the License at
!
!      http://www.apache.org/licenses/LICENSE-2.0
!
!  Unless required by applicable law or agreed to in writing, software
!  distributed under the License is distributed on an "AS IS" BASIS,
!  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
!  See the License for the specific language governing permissions and
!  limitations under the License.
!
module eigen_subdiag_sub
  implicit none

  public :: eigen_real8_pdsyev
  public :: eigen_subdiag, eigen_subdiag_periodic

private

contains
  !  nb: blocking factor
  !      probably parameter relating to efficiency
  !      pdsyev uses block-cyclic distribution for efficient parallel-computation
  subroutine init_scalapack(pinfo,info,n,nb)
    use structures, only: s_process_info, s_orbital_parallel
    implicit none
    integer :: NUMROC

    type(s_process_info),intent(inout)  :: pinfo
    type(s_orbital_parallel),intent(in) :: info
    integer,intent(in) :: n,nb

    integer :: ii,ix,iy,iz,k1,k2,ierr
    integer :: len_iwork,len_work0,trilwmin
    integer :: ictxt
    real(8) :: rtmp(1)
    integer, allocatable :: iwork(:)
    real(8), allocatable :: h_div(:,:), v_div(:,:), e(:)

    pinfo%nprow = int(sqrt(dble(info%isize_r)))
    do ii=1,100
      pinfo%npcol=info%isize_r/pinfo%nprow
      if(pinfo%npcol*pinfo%nprow == info%isize_r) exit
      pinfo%nprow=pinfo%nprow-1
    end do

    if (pinfo%npcol*pinfo%nprow /= info%isize_r) &
      stop 'eigen_subdiag_scalapack: fatal error, please check nprow and npcol'

    allocate( pinfo%usermap(pinfo%nprow,pinfo%npcol) )
    pinfo%usermap = - 1
    ii = 0
    do iz=0,pinfo%nprgrid(3)-1
    do iy=0,pinfo%nprgrid(2)-1
    do ix=0,pinfo%nprgrid(1)-1
      ii=ii+1
      k1=mod(ii-1,pinfo%nprow)
      k2=(ii-1)/pinfo%nprow
      pinfo%usermap(k1+1,k2+1) = info%imap(ix,iy,iz,info%iaddress(4),info%iaddress(5))
    end do
    end do
    end do

    if (ii /= info%isize_r) &
      stop 'eigen_subdiag_scalapack: fatal error, please check usermap'

    call BLACS_PINFO( pinfo%iam, pinfo%nprocs )
    IF (pinfo%nprocs < 1) THEN
      pinfo%nprocs = info%isize_r
      call BLACS_SETUP( pinfo%iam, pinfo%nprocs )
    END IF

    call BLACS_GET( 0, 0, ictxt )
    call BLACS_GRIDMAP( ictxt, pinfo%usermap, pinfo%nprow, pinfo%nprow, pinfo%npcol )
    call BLACS_GRIDINFO( ictxt, pinfo%nprow, pinfo%npcol, pinfo%myrow, pinfo%mycol )
    pinfo%nrow_local = NUMROC( n, nb, pinfo%myrow, 0, pinfo%nprow )
    pinfo%ncol_local = NUMROC( n, nb, pinfo%mycol, 0, pinfo%npcol )
    pinfo%lda        = max(1, pinfo%nrow_local)

    call DESCINIT( pinfo%desca, n, n, nb, nb, 0, 0, ictxt, pinfo%lda, ierr )
    call DESCINIT( pinfo%descz, n, n, nb, nb, 0, 0, ictxt, pinfo%lda, ierr )

    len_iwork = 2 + 7*n + 8*pinfo%npcol
    allocate( h_div(pinfo%nrow_local,pinfo%ncol_local), &
              v_div(pinfo%nrow_local,pinfo%ncol_local), &
              e(n), iwork(len_iwork) )

    ! determine the working memory size from PDSYEVD
    trilwmin = 3*n + max( nb*(pinfo%nrow_local+1), 3*nb )
    len_work0 = max( 1+6*n+2*pinfo%nrow_local*pinfo%ncol_local, trilwmin ) + 2*n
    call PDSYEVD( 'V', 'U', n, h_div, nb, nb, pinfo%desca, e, v_div, nb, nb, pinfo%descz, &
                  rtmp, -1, iwork, len_iwork, ierr )
    pinfo%len_work = max( nint(rtmp(1))*10, len_work0*10 )
    deallocate( iwork, e, v_div, h_div )

    pinfo%flag_blacs_gridinit = .true.
  end subroutine init_scalapack

  subroutine eigen_real8_pdsyev(pinfo,info,h,e,v)
    use structures, only: s_process_info, s_orbital_parallel
    use communication, only: comm_summation, comm_is_root
    implicit none
    type(s_process_info)                :: pinfo
    type(s_orbital_parallel),intent(in) :: info
    real(8), intent(in)  :: h(:,:)
    real(8), intent(out) :: e(:)
    real(8), intent(out) :: v(:,:)
    integer :: n, nb
    integer :: len_iwork
    integer :: i, j, ierr
    integer :: i_loc, j_loc, proc_row, proc_col
    integer, allocatable :: work(:), iwork(:)
    real(8), allocatable :: h_div(:,:), v_div(:,:), v_tmp(:,:)

    n  = ubound(h,1)

    if (.not. pinfo%flag_blacs_gridinit) then
      call init_scalapack(pinfo, info, n, 1)
    end if

    len_iwork = 2 + 7*n + 8*pinfo%npcol

    allocate( h_div(pinfo%nrow_local,pinfo%ncol_local), &
              v_div(pinfo%nrow_local,pinfo%ncol_local), &
              v_tmp(n,n), iwork(len_iwork), work(pinfo%len_work) )

!$omp parallel do private(i,j,i_loc,j_loc,proc_row,proc_col)
    do i=1,n
    do j=1,n
      call INFOG2L( i, j, pinfo%desca, pinfo%nprow, pinfo%npcol, pinfo%myrow, pinfo%mycol, i_loc, j_loc, proc_row, proc_col )
      if (pinfo%myrow == proc_row .and. pinfo%mycol == proc_col) then
        h_div(i_loc,j_loc) = h(i,j)
      end if
    end do
    end do

    call PDSYEVD( 'V', 'U', n, h_div, nb, nb, pinfo%desca, e, v_div, nb, nb, pinfo%descz, &
                  work, pinfo%len_work, iwork, len_iwork, ierr )

    v_tmp=0d0
!$omp parallel do private(i,j,i_loc,j_loc,proc_row,proc_col)
    do i=1,n
    do j=1,n
      call INFOG2L( i, j, pinfo%descz, pinfo%nprow, pinfo%npcol, pinfo%myrow, pinfo%mycol, i_loc, j_loc, proc_row, proc_col )
      if (pinfo%myrow == proc_row .and. pinfo%mycol == proc_col) then
        v_tmp(i,j) = v_div(i_loc,j_loc)
      end if
    end do
    end do

    call comm_summation(v_tmp, v, n*n, info%icomm_r)

    deallocate( work, iwork, h_div, v_div, v_tmp )

    return
  end subroutine eigen_real8_pdsyev

!----------------------------------------------------------------
subroutine eigen_subdiag(Rmat,evec,iter,ier2)
  implicit none

  integer :: iter,ier2
  real(8) :: Rmat(iter,iter)
  real(8) :: evec(iter,iter)

  character(1) :: JOBZ,UPLO
  integer :: N
  real(8) :: A(iter,iter)
  integer :: LDA
  real(8) :: W(iter)
  real(8) :: WORK(3*iter-1)
  integer :: LWORK

  ier2=0

  JOBZ='V'
  UPLO='L'
  N=iter
  A=Rmat
  LDA=iter
  LWORK=3*iter-1
  call DSYEV(JOBZ,UPLO,N,A,LDA,W,WORK,LWORK,ier2)
  evec=A

end subroutine eigen_subdiag

subroutine eigen_subdiag_periodic(Rmat,evec,iter,ier2)
  implicit none
  character :: JOBZ, UPLO
  integer :: LWORK
  integer :: iter,ier2
  real(8),allocatable :: RWORK(:)
  real(8) :: W(iter)
  complex(8) :: Rmat(iter,iter)
  complex(8),allocatable :: WORK(:)
  complex(8) :: evec(iter,iter)

  ier2=0

  JOBZ='V'
  UPLO='U'

  LWORK=2*iter-1
  allocate(WORK(LWORK))
  allocate(RWORK(3*iter-2))

  call ZHEEV(JOBZ,UPLO,iter,Rmat,iter,W,WORK,LWORK,RWORK,ier2)

  evec(:,:)=Rmat(:,:)

  deallocate(WORK,RWORK)

end subroutine eigen_subdiag_periodic

end module eigen_subdiag_sub

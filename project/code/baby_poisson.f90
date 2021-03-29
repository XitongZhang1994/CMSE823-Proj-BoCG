module type_defs
  integer, parameter:: sp = kind(1.0),&
    dp = selected_real_kind(2*precision(1.0_sp)),&
    qp = selected_real_kind(2*precision(1.0_dp))
end module type_defs

module problem_setup
  use type_defs
  implicit none
  integer,  parameter :: Nx = 1000
  logical, parameter :: dirichlet_bc = .false.
  logical, parameter :: use_direct = .false. 
  real(dp), parameter :: TOL = 1.0e-12_dp
  character (len=40) :: method= 'SD'
end module problem_setup

module arrs
  use type_defs
  implicit none
  real(dp), allocatable, dimension(:) :: u,b,x
end module arrs

module afuns
  
contains
  subroutine apply_1D_laplacian_D(au,u,n)
    use type_defs
    implicit none
    integer, intent(in) :: n
    real(dp), intent(out) :: au(n)
    real(dp), intent(in)  ::  u(n)
    integer :: i
    Au(1) = (u(2) - 2.0_dp*u(1)         )
    Au(n) = (     - 2.0_dp*u(n) + u(n-1))
    do i = 2,n-1
     Au(i)= (u(i+1) - 2.0_dp*u(i) + u(i-1))
    end do
    
  end subroutine apply_1D_laplacian_D

  subroutine apply_1D_laplacian_N(au,u,n)
    use type_defs
    implicit none
    integer, intent(in) :: n
    real(dp), intent(out) :: au(n)
    real(dp), intent(in)  ::  u(n)
    integer :: i
    Au(1) =   (u(2)   -        u(1)         )
    Au(n) =   (       -        u(n) + u(n-1))
    do i = 2,n-1
       Au(i)= (u(i+1) - 2.0_dp*u(i) + u(i-1))
    end do
    
  end subroutine apply_1D_laplacian_N

end module afuns

module iterative_solver_D
  use type_defs
  implicit none
  real(dp), allocatable, dimension(:) :: r_isd,x_isd,Ar_isd,p
  real(dp), allocatable, dimension(:,:) :: r_t, p_t, x_t
  real(dp) :: TOL_ISD
contains
  subroutine set_tol_isd(tol)
    implicit none
    real(dp) :: tol
    TOL_ISD = tol
  end subroutine set_tol_isd
  
  subroutine allocate_isd(n)
    implicit none
    integer, intent(in) :: n
    allocate(r_t(1,n),r_isd(n),x_isd(n),x_t(1,n),Ar_isd(n),p(n),p_t(1,n))
  end subroutine allocate_isd

  subroutine deallocate_isd
    implicit none
    deallocate(r_isd,x_isd,Ar_isd)
  end subroutine deallocate_isd
  
  subroutine bicg_d(x,b,n)
    use type_defs
    use afuns
    implicit none
    integer, intent(in) :: n
    real(dp), intent(inout)  :: x(n)
    real(dp), intent(inout)  :: b(n)
    real(dp) :: res_norm2,res_norm20,alpha,res_norm2_t,beta_d,beta_n,beta
    integer :: iter    
    x_isd = 0.0_dp
    x_t = 0.0_dp
    r_isd = b
    p = b
    r_t(1,:) = b
    p_t(1,:) = b

    res_norm20 = sum(r_isd**2)
    res_norm2 = res_norm20
    iter = 0
  
    do while ((res_norm2/res_norm20 .gt. TOL_ISD**2) &
         .and. (iter .lt. 10000)) 
       call apply_1D_laplacian_D(Ar_isd,p,n)
       
       beta_d = sum(r_t(1,:)*r_isd)
       alpha = beta_d / sum(p_t(1,:)*Ar_isd)
       
       x_isd = x_isd + alpha*p
       x_t   = x_t   + alpha*p_t

       r_isd = r_isd - alpha*Ar_isd 
       call apply_1D_laplacian_D(Ar_isd,p_t(1,:),n)
       r_t(1,:) = r_t(1,:) - alpha*Ar_isd 

       beta_n   = sum(r_t(1,:)*r_isd)
       beta     = beta_n/beta_d
       
       p   = r_isd  + beta*p
       p_t = r_t    + beta*p_t

       res_norm2 = sum(r_isd**2)
       res_norm2_t = sum(r_t**2)
       
       iter = iter + 1
       write(*,*) iter, sqrt(res_norm2) 
    end do
    x = x_isd
  end subroutine bicg_d

  subroutine steep_descent_d(x,b,n)
    use type_defs
    use afuns
    implicit none
    integer, intent(in) :: n
    real(dp), intent(inout)  :: x(n)
    real(dp), intent(inout)  :: b(n)
    real(dp) :: res_norm2,res_norm20,alpha
    integer :: iter    
    x_isd = 0.0_dp
    r_isd = b
    res_norm20 = sum(r_isd**2)
    res_norm2 = res_norm20
    iter = 0
    do while ((res_norm2/res_norm20 .gt. TOL_ISD**2) &
         .and. (iter .lt. 10000)) 
       call apply_1D_laplacian_D(Ar_isd,r_isd,n)
       alpha = res_norm2 / sum(r_isd*Ar_isd)
       x_isd = x_isd + alpha*r_isd
       r_isd = r_isd - alpha*Ar_isd       
       res_norm2 = sum(r_isd**2)
       iter = iter + 1
       write(*,*) iter, sqrt(res_norm2) 
    end do
    x = x_isd
  end subroutine steep_descent_d
end module iterative_solver_D

module iterative_solver_N
  use type_defs
  implicit none
  real(dp), allocatable, dimension(:) :: r_isn,x_isn,Ar_isn
  real(dp) :: TOL_ISN
contains
  
  subroutine set_tol_isn(tol)
    implicit none
    real(dp) :: tol
    TOL_ISN = tol
  end subroutine set_tol_isn
  
  subroutine allocate_isn(n)
    implicit none
    integer, intent(in) :: n
    allocate(r_isn(n),x_isn(n),Ar_isn(n))
  end subroutine allocate_isn
  
  subroutine deallocate_isn
    implicit none
    deallocate(r_isn,x_isn,Ar_isn)
  end subroutine deallocate_isn

  ! FIX ME PLEASE
  subroutine steep_descent_N(x,b,n)
    use type_defs
    use afuns
    implicit none
    integer, intent(in) :: n
    real(dp), intent(inout)  :: x(n)
    real(dp), intent(inout)  :: b(n)
    real(dp) :: res_norm2,res_norm20,alpha
    integer :: iter,i
    x_isn = 0.0_dp
    r_isn = b
    res_norm20 = sum(r_isn**2)
    res_norm2 = res_norm20
    iter = 0
    do while ((res_norm2/res_norm20 .gt. TOL_ISN**2) &
        .and. (iter .lt. 1000000))
      call apply_1D_laplacian_N(Ar_isn,r_isn,n)
      alpha = res_norm2 / sum(r_isn*Ar_isn)
      x_isn = x_isn + alpha*r_isn
      r_isn = r_isn - alpha*Ar_isn
      res_norm2 = sum(r_isn**2)
      iter = iter + 1
      write(*,*) iter, sqrt(res_norm2)
    end do
    x = x_isn
  end subroutine steep_descent_N

end module iterative_solver_N

program ins
  use type_defs
  use problem_setup
  use arrs
  use afuns
  use iterative_solver_D
  use iterative_solver_N
  implicit none
  ! This program solves u_xx = f 
  ! on the domain [x] \in [0,1] with either Dirichlet or Neumann BC
  ! hx = 1/Nx
  real(dp) :: hx
  integer :: i,j,n_iter,N_sys,info  
  real(dp), allocatable, dimension(:,:) :: A
  real(dp), allocatable, dimension(:) :: action_of_A,u_inner
  integer, allocatable, dimension(:) ::  ipiv
  ! Set up the grid
  hx = 1.0_dp/real(Nx,dp)
  allocate(x(0:nx))
  allocate(u(0:nx))
  do i = 0,nx
   x(i) = real(i,dp)*hx
  end do

  if(dirichlet_bc) then
     ! For Dirichlet BC we don't solve for the boundary conditions. 
     N_sys = nx-1
  else
     ! For Neumann BC the solution at the first and last gridpoint is
     ! part of the solve.
     N_sys = nx+2
     ! Depending on what you want to do you may also need a nonsingular system...
  end if
  
  allocate(b(N_sys))
  
  if (use_direct) then
     allocate(A(N_sys,N_sys),&
          action_of_A(N_sys),&
          u_inner(N_sys),&
          ipiv(N_sys))
     if(dirichlet_bc) then
        do i = 1,N_sys
           u_inner = 0.0
           u_inner(i) = 1.0d0
           call apply_1D_laplacian_D(action_of_A,u_inner,N_sys)
           A(:,i) = action_of_A
        end do
     else
        ! FIX ME
        do i = 1,N_sys-1
            u_inner = 0.0
            u_inner(i) = 1.0d0
            call apply_1D_laplacian_N(action_of_A,u_inner,N_sys-1)
            A(:,i) = action_of_A
        end do
        do i = 1,N_sys-1
            A(i,N_sys) = 1
            A(N_sys,i) = 1
        end do
        A(N_sys,N_sys)=0
     end if
  end if

  ! Set up the problem.
  ! We cook up a problem with a known solution.
  ! Say that u(x) = exp(-x), then we must have that
  ! f = u_xx  = exp(-x),
  ! u(x = 0) = exp(0), u(x = 1) = exp(-1)
  ! or
  ! u_x(x = 0) = -exp(0), u_x(x = 1) = -exp(-1)
  !
  ! We move the hx^2 from the denominator over to the right hand side of the
  ! system of equations.

  if (dirichlet_bc) then
     do i = 1,nx-1
        b(i) = hx*hx*exp(-x(i))
     end do
     ! We must also account for the boundary conditions
     b(1) = b(1) - exp(-x(0))
     b(nx-1) = b(nx-1) - exp(-x(nx))

     if (use_direct) then
        CALL DGETRF(N_sys,N_sys,A,N_sys,ipiv,INFO)
        CALL DGETRS('N',N_sys,1,A,N_sys,IPIV,b,N_sys,INFO)
        u(1:nx-1) = b 
     else
        call allocate_isd(N_sys)
        call set_tol_isd(tol)
        !call steep_descent gradient
        if (method == "SD") then
          call steep_descent_d(u(1:nx),b,N_sys)
        !call bi-conjugate gradient
        elseif (method == "BI") then
          call bicg_d(u(1:nx),b,N_sys)
        end if
        call deallocate_isd
     end if
     u(0) = exp(-x(0))
     u(nx) = exp(-x(nx))
     write(*,*) maxval(abs(u - exp(-x)))
     
  else
     do i = 1,nx+1
        b(i) = hx*hx*exp(-x(i-1))
     end do
     ! We must also account for the boundary conditions
     ! Here we have that u(1) - 2*u(0) + u(-1) = h*h*exp(-x(0))
     ! And we approximate u_x(x = 0) = -exp(0) by
     ! u(1) - u(-1) = 2*h * (-exp(0))
     ! Plug in
     ! 2*u(1) - 2*u(0) = h*h*exp(-x(0)) + 2*h*(-exp(0)) 
     ! We scale this by 1/2 to make the matrix symmetric
     b(1) = 0.5_dp*b(1) - hx*exp(-x(0))
     b(nx+1) = 0.5_dp*b(nx+1) + hx*exp(-x(nx))
     b(nx+2) = 0
     if (use_direct) then
        CALL DGETRF(N_sys,N_sys,A,N_sys,ipiv,INFO)
        CALL DGETRS('N',N_sys,1,A,N_sys,IPIV,b,N_sys,INFO)
        u(0:nx) = b(1:nx+1)
     else
        ! FIX ME
        if (method == "SD") then
          call allocate_isn(N_sys)
          call set_tol_isn(tol)
          call steep_descent_N(u(0:nx),b(1:nx+1),N_sys-1)
          call deallocate_isn
        end if
     end if
     write(*,*) maxval(abs(u - (exp(-x) -1.0d0+exp(-1.0d0) )))
  end if
    
end program ins

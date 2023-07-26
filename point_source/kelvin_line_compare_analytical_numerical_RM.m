% script to evluate analytically and with various popular numerical
% integration techniques a Kelvin point source with uniform strength
% integrated over a line from -1<=x<=1 and y = 0
% 
% Rishav Mallick, 2023, Caltech Seismolab

clear 

%% Set model parameters 
% Elasticity parameters
mu_val = 1;
nu_val = 0.25;

fx_val = 0;
fy_val = -1;
y0_val = 0;

% provide plotting type (2-d grid or 1-d line)
% 0 - line, 
% 1 - xy grid
eval_type = 1;

n_pts = 51;
x_vec = linspace(-2, 2, n_pts);
y_vec = linspace(-1.5, 1.5, n_pts);

if eval_type == 1
    % create a box grid of points
    [x_mat, y_mat] = meshgrid(x_vec, y_vec);
else
    % only evluate function along a line at y=0
    x_mat = x_vec;
    y_mat = x_vec.*0;
end

%% analytical solution
tic
% Declare symbols and build functions to integrate
syms x0 y0 g nu mu xoffset yoffset fx fy
x = x0 - xoffset;
y = y0 - yoffset;
C = 1 / (4 * pi * (1 - nu));
r = sqrt(x^2 + y^2);
g = -C * log(r);
gx = -C * x / (x^2 + y^2);
gy = -C * y / (x^2 + y^2);

ux = fx / (2 * mu) * ((3 - 4 * nu) * g - x * gx) + fy / (2 * mu) * (-y * gx);
uy = fx / (2 * mu) * (-x * gy) + fy / (2 * mu) * ((3 - 4 * nu) * g - y * gy);

% Try integrating the various displacement & stress components along a line
% defined as 1-<= x0 <= 1, y0 = 0
ux_definite = int(ux, x0, [-1.0 1.0]);
uy_definite = int(uy, x0, [-1.0 1.0]);
toc

% Convert to function
ux_function_handle = matlabFunction(ux_definite);
uy_function_handle = matlabFunction(uy_definite);

% evaluate expressions at points
ux_mat = zeros(size(x_mat));
uy_mat = zeros(size(x_mat));

tic
if eval_type == 1
    for i=1:n_pts
        for j=1:n_pts            
            ux_mat(i, j) = ux_function_handle(fx_val, fy_val, mu_val, nu_val, x_mat(i, j), y0_val, y_mat(i, j));
            uy_mat(i, j) = uy_function_handle(fx_val, fy_val, mu_val, nu_val, x_mat(i, j), y0_val, y_mat(i, j));
        end
    end
else
    for i = 1:n_pts
        ux_mat(i) = ux_function_handle(fx_val, fy_val, mu_val, nu_val , x_mat(i), y0_val, y_mat(i));
        uy_mat(i) = uy_function_handle(fx_val, fy_val, mu_val, nu_val , x_mat(i), y0_val, y_mat(i));
    end
end
toc

% Plot result over a grid
figure(1),clf
if eval_type == 1
    figure(1)
    toplot = sqrt(ux_mat.^2 + uy_mat.^2);
    contourf(x_mat, y_mat, toplot,5), hold on
    quiver(x_mat(:),y_mat(:),ux_mat(:),uy_mat(:),'r','Linewidth',1)
    cb=colorbar;cb.Label.String = '|u|';
    % clim([0,1].*max(abs(toplot(:))))
    clim([0,1*0.2])
    axis("equal")
    colormap(sky(10))
    title('(u_x,u_y) analytical solution')
    set(gca,'Fontsize',15)    
else
    figure(1)
    plot(x_mat,ux_mat,'-','LineWidth',3), hold on
    plot(x_mat,uy_mat,'-','LineWidth',3)
    plot([-1,1],[0,0],'k-','Linewidth',2)
    axis tight, grid on
    xlabel('x'), ylabel('u')  
    legend('u_x','u_y')
    title('(u_x,u_y) analytical solution')
end

%% numerical integration (GL quadrature)

ux_numeric_GL = zeros(size(x_mat));
uy_numeric_GL = zeros(size(x_mat));

N_gl = 39;
[xk,wk] = calc_gausslegendre_weights(N_gl);

tic
for k=1:numel(xk)
    [n_ux, n_uy] = kelvin_point(x_mat, y_mat, xk(k), y0_val, fx_val, fy_val, mu_val, nu_val);
    ux_numeric_GL = ux_numeric_GL + n_ux.*wk(k);
    uy_numeric_GL = uy_numeric_GL + n_uy.*wk(k);
end
toc

%% compute solution using tanh-sinh quadrature

ux_numeric_TS = zeros(size(x_mat));
uy_numeric_TS = zeros(size(x_mat));

% numerical solution
h=0.05;% step size for tanh-sinh
n=fix(2/h);

for k=-n:n    
    wk=(0.5*h*pi*cosh(k*h))./(cosh(0.5*pi*sinh(k*h))).^2;
    xk=tanh(0.5*pi*sinh(k*h));
    [n_ux, n_uy] = kelvin_point(x_mat, y_mat, xk, y0_val, fx_val, fy_val, mu_val, nu_val);
    ux_numeric_TS = ux_numeric_TS + n_ux.*wk;
    uy_numeric_TS = uy_numeric_TS + n_uy.*wk;
end

%% compute solution using integral
ux_numeric_int = zeros(size(x_mat));
uy_numeric_int = zeros(size(x_mat));

tic
for k=1:numel(x_mat)    
    ux_numeric_int(k) = integral(@(x0) gf_x(x_mat(k),y_mat(k),x0, y0_val, fx_val, fy_val, mu_val, nu_val),-1,1);
    uy_numeric_int(k) = integral(@(x0) gf_y(x_mat(k),y_mat(k),x0, y0_val, fx_val, fy_val, mu_val, nu_val),-1,1);
end
toc

%% plot comparison of solutions
figure(2),clf
if eval_type==1
    subplot(3,1,1)
    toplot_a = sqrt(ux_mat.^2 + uy_mat.^2);
    contourf(x_mat, y_mat, toplot_a)
    colorbar;
    clim([0,1].*max(abs(toplot_a(:))))
    axis("equal")
    title("analytical solution")
    set(gca,'Fontsize',12)

    subplot(3,1,2)
    toplot_n = sqrt(ux_numeric_GL.^2 + uy_numeric_GL.^2);
    % toplot_n = sqrt(ux_numeric_TS.^2 + uy_numeric_TS.^2);
    contourf(x_mat, y_mat, toplot_n)
    colorbar;
    clim([0,1].*max(abs(toplot_n(:))))
    axis("equal")
    title(['Gauss-Legendre numerical integration of order ' num2str(N_gl)])
    set(gca,'Fontsize',12)

    % plot residuals as % of analytical solution
    subplot(3,1,3)
    contourf(x_mat, y_mat, 100.*(toplot_a - toplot_n)./toplot_a)
    cb=colorbar;cb.Label.String = '% residuals';
    clim([-1,1].*10)
    axis("equal")
    colormap(parula(40))
    title('Residuals %(analytical - numerical)')
    set(gca,'Fontsize',12)
else
    subplot(2,1,1)
    plot(x_mat,ux_mat,'-','LineWidth',4), hold on
    plot(x_mat,ux_numeric_GL,'-','LineWidth',1)
    plot(x_mat,ux_numeric_TS,'k-','LineWidth',1)
    plot(x_mat,ux_numeric_int,'g--','LineWidth',2)
    plot([-1,1],[0,0],'k-','Linewidth',2)
    axis tight, grid on
    xlabel('x'), ylabel('u_x')
    legend('analytical','GL-quadrature','TS-quadrature','adaptive')
    set(gca,'FontSize',15)

    subplot(2,1,2)
    plot(x_mat,uy_mat,'-','LineWidth',4), hold on
    plot(x_mat,uy_numeric_GL,'-','LineWidth',1)
    plot(x_mat,uy_numeric_TS,'k-','LineWidth',1)
    plot(x_mat,uy_numeric_int,'g--','LineWidth',2)
    plot([-1,1],[0,0],'k-','Linewidth',2)
    axis tight, grid on
    xlabel('x'), ylabel('u_y')
    set(gca,'FontSize',15)

    figure(10),clf
    plot(x_mat,ux_mat-ux_numeric_TS,'k-','LineWidth',1), hold on
    plot(x_mat,ux_mat-ux_numeric_int,'g--','LineWidth',2)
    axis tight, grid on
    xlabel('x'), ylabel('residual u_x')
    legend('TS-quadrature','adaptive')
    set(gca,'FontSize',15)

end

%% define kelvin point source function
function ux = gf_x(x0, y0, xoffset, yoffset, fx, fy, mu, nu)
[ux, ~] = kelvin_point(x0, y0, xoffset, yoffset, fx, fy, mu, nu);
end
function uy = gf_y(x0, y0, xoffset, yoffset, fx, fy, mu, nu)
[~, uy] = kelvin_point(x0, y0, xoffset, yoffset, fx, fy, mu, nu);
end

function [ux, uy] = kelvin_point(x0, y0, xoffset, yoffset, fx, fy, mu, nu)
x = x0 - xoffset;
y = y0 - yoffset;
C = 1 / (4 * pi * (1 - nu));
r = sqrt(x.^2 + y.^2);
g = -C .* log(r);
gx = -C .* x ./ (x.^2 + y.^2);
gy = -C .* y ./ (x.^2 + y.^2);
ux = fx / (2 * mu) * ((3 - 4 * nu) .* g - x .* gx) + fy / (2 * mu) .* (-y .* gx);
uy = fx / (2 * mu) * (-x .* gy) + fy / (2 * mu) * ((3 - 4 * nu) .* g - y .* gy);
end
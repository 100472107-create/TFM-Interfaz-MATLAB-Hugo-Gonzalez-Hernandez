# TFM-Interfaz-MATLAB-Hugo-Gonzalez-Hernandez
Interfaz gráfica desarrollada en MATLAB para el TFM del Máster de Energías Renovables en Sistemas Térmicos

## Contenido del repositorio

```
WIND_UI_live.m          # Interfaz gráfica principal
WIND_coreN.m            # Núcleo BEM para N perfiles y N-1 cortes
CPfun.m                 # Cálculo del coeficiente de potencia CP
eqnsNew.m               # Sistema de ecuaciones BEM
objective_fun.m         
controlCurves.m         # Curvas de control 
powerCurve.m            # Curva de potencia del aerogenerador
KVpow3.m                
VNpow3.m                
Rpow3.m                
avePow3.m               
read_polars.m           # Lectura de polares aerodinámicas desde CSV
caso_referencia.mat     # Caso de referencia guardado
data-*.csv              # Polares aerodinámicas por perfil (XFOIL)
```

## Requisitos
- **MATLAB R2021a o superior** (se recomienda R2023a+)
- **Optimization Toolbox** (`fsolve`, `fmincon`)
- Los archivos `data-*.csv` deben estar en la misma carpeta que los `.m`

## Uso
1. Colocar todos los archivos `.m` y `data-*.csv` en una misma carpeta.
2. Abrir MATLAB y establecer esa carpeta como directorio de trabajo.
3. Ejecutar en la consola el código: WIND_UI_live.m
4. La interfaz se abre con cuatro pestañas:
   - **Optimización** — selección de perfiles y cortes, cálculo de CP(λ)
   - **Análisis** — dimensionado del rotor (R, FC, KV) en función de PN y parámetros de viento
   - **Potencia & Control** — curva de potencia y curvas de control (pitch / stall activo)
   - **⚙ Opciones** — parámetros avanzados (b, xR, NX, rango de λ, eficiencias)

## Autor
**Hugo González Hernández**  
Máster en Energías Renovables en Sistemas Térmicos  
Universidad Carlos III de Madrid  
Junio 2026

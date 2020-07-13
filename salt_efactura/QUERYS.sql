begin work;

INSERT INTO tabla (sucursal, nomtabla, codigo, descripcion, valor_alf, fecha_activacion
)values('0000', 'PATH', 'SLTIN', 'carpeta entrada', '/fs/migracion/Extracciones/SALESFORCE/T1/SALT/', today);

INSERT INTO tabla (sucursal, nomtabla, codigo, descripcion, valor_alf, fecha_activacion
)values('0000', 'PATH', 'SLTLOG', 'carpeta log', '/fs/migracion/Extracciones/SALESFORCE/T1/SALT/', today);

INSERT INTO tabla (sucursal, nomtabla, codigo, descripcion, valor_alf, fecha_activacion
)values('0000', 'PATH', 'SLTBAD', 'carpeta malos', '/fs/migracion/Extracciones/SALESFORCE/T1/SALT/', today);

INSERT INTO tabla (sucursal, nomtabla, codigo, descripcion, valor_alf, fecha_activacion
)values('0000', 'PATH', 'SLTOUT', 'carpeta repositorio', '/fs/migracion/Extracciones/SALESFORCE/T1/SALT/', today);

commit work;

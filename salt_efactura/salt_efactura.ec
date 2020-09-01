/********************************************************************************
    Proyecto: Interfaces SALT Salesforces - MAC
    Aplicacion: salt_efactura
    
	Fecha : 10/07/2020

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		ABM de E-Factura
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <synergia>
		
		<Nro.Cliente>: Opcional

********************************************************************************/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>
#include "directory.h"
#include "retornavar.h"

$include "salt_efactura.h";

/* Variables Globales */
FILE	*pFileEntrada;
FILE	*pFileLog;

char	sArchivoEntrada[100];
char	sSoloArchivoEntrada[100];

char  sArchivoTrabajo[100];

char	sArchivoLog[100];
char	sSoloArchivoLog[100];

char	FechaGeneracion[9];	

char	MsgControl[100];
$char	fecha[9];
int	iExisteDebito;

long	cantProcesada;
long  clientesProcesados;
long  clientesRechazados;


char	sMensMail[1024];	

/* Variables Globales Host */
$char	sPathEntrada[100];
$char	sPathLog[100];
$char	sPathMalos[100];
$char	sPathRepo[100];

$long	lFechaLimiteInferior;
$int	iCorrelativos;
$dtime_t    gtInicioCorrida;

$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
Tdir    *TdirLotes;
char		unxCmd[500];

	if(! AnalizarParametros(argc, argv)){
		exit(0);
	}
	
	hora = time(&hora);
	
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));
	
	strcpy(nombreBase, argv[1]);
	
	$DATABASE :nombreBase;	
	
	$SET LOCK MODE TO WAIT 120;
	$SET ISOLATION TO DIRTY READ;
	

	CreaPrepare();


	if (!CargarPaths()){
		printf("No se pudo cargar los paths\nSe aborta el programa.");
		exit(1);
	}
	
		
	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */
   dtcurrent(&gtInicioCorrida);
   
	cantProcesada=0;
	clientesProcesados=0;
	
/* ************ BUSCA ARCHIVOS *********** */
	TdirLotes = DirectoryOpen(sPathEntrada);
	if (TdirLotes->dir == NULL){
			 printf("\nERROR al abrirDirectorio\n");
			 exit(1);
	}

	while (DirectoryFetch(TdirLotes, "n", sSoloArchivoEntrada)){
		if(ArchivoValido(sSoloArchivoEntrada)){
			memset(sArchivoTrabajo, '\0', sizeof(sArchivoTrabajo));
			memset(unxCmd, '\0', sizeof(unxCmd));


			sprintf(sArchivoTrabajo, "%s%s", sPathEntrada, sSoloArchivoEntrada);
/*			
			sprintf(sArchivoTrabajo, "%s%s.txt", sPathRepo, sSoloArchivoEntrada);
			
			sprintf(unxCmd, "dos2ux %s%s > %s ", sPathEntrada, sSoloArchivoEntrada, sArchivoTrabajo);
			if (system(unxCmd) != 0){
				printf("Error al convertir archivo [%s] a Unix.\n%s", sSoloArchivoEntrada, unxCmd);
				exit(1);
			}
			
			sprintf(unxCmd, "mv -f %s%s %s%s", sPathEntrada, sSoloArchivoEntrada, sPathRepo, sSoloArchivoEntrada);
			if (system(unxCmd) != 0){
				printf("Error al mover archivo [%s] al repositorio.\n", sSoloArchivoEntrada);
				exit(1);
			}
*/

			
			
			if(! AbreArchivos(sSoloArchivoEntrada, sArchivoTrabajo)){
				exit(1);
			}
			if(ProcesaArchivo()){
				cantProcesada++;
				sprintf(unxCmd, "mv -f %s%s %s%s", sPathEntrada, sSoloArchivoEntrada, sPathRepo, sSoloArchivoEntrada);
				if (system(unxCmd) != 0){
					printf("Error al mover archivo [%s] al repositorio.\n", sSoloArchivoEntrada);
					exit(1);
				}				
/*				
				sprintf(unxCmd, "rm -f %s", sArchivoTrabajo);
				if (system(unxCmd) != 0){
					printf("Error al borrar archivo [%s] ya procesado.\n", sArchivoTrabajo);
					exit(1);
				}				
*/				
			}else{
				printf("Archivo [%s] NO se pudo procesar\n", sSoloArchivoEntrada);
				sprintf(unxCmd, "rm -f %s", sArchivoTrabajo);
			}	
		}else{
			printf("Archivo [%s] NO valido\n", sSoloArchivoEntrada);
		}
	}

/* ************ TERMINA CON LOS ARCHIVOS *********** */

	$CLOSE DATABASE;

	$DISCONNECT CURRENT;

	/* ********************************************
				FIN AREA DE PROCESO
	********************************************* */

	printf("==============================================\n");
	printf("SALT_EFACTURA.\n");
	printf("==============================================\n");
	printf("Proceso Concluido.\n");
	printf("==============================================\n");
	printf("Archivos procesados : %ld \n",cantProcesada);
	printf("Clientes procesados : %ld \n",clientesProcesados);
	printf("Clientes Rechazados : %ld \n",clientesRechazados);
	printf("==============================================\n");
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));						

	hora = time(&hora);
	printf("\nHora de finalizacion del proceso : %s\n", ctime(&hora));

	printf("Fin del proceso OK\n");	

	exit(0);
}	

short AnalizarParametros(argc, argv)
int		argc;
char	* argv[];
{
	if(argc != 2){
		MensajeParametros();
		return 0;
	}
	
	return 1;
}

void MensajeParametros(void){
		printf("Error en Parametros.\n");
		printf("	<Base> = synergia.\n");
}


short CargarPaths(void){
	memset(sPathEntrada, '\0', sizeof(sPathEntrada));
	memset(sPathLog, '\0', sizeof(sPathLog));
	memset(sPathMalos, '\0', sizeof(sPathMalos));
	memset(sPathRepo, '\0', sizeof(sPathRepo));

	$EXECUTE selRutaIn INTO :sPathEntrada;
	
	if(SQLCODE != 0){
		printf("Error al buscar path entrada.\n");
		return 0;
	}
	
	alltrim(sPathEntrada, ' ');
	strcat(sPathEntrada, "data_in/");
	
	$EXECUTE selRutaLog INTO :sPathLog;
	
	if(SQLCODE != 0){
		printf("Error al buscar path logs.\n");
		return 0;
	}
	
	alltrim(sPathLog, ' ');
	strcat(sPathLog, "data_log/");
		
	$EXECUTE selRutaMalos INTO :sPathMalos;
	
	if(SQLCODE != 0){
		printf("Error al buscar path malos.\n");
		return 0;
	}
		
	alltrim(sPathMalos, ' ');
	strcat(sPathMalos, "data_malos/");
			
	$EXECUTE selRutaOut INTO :sPathRepo;
	
	if(SQLCODE != 0){
		printf("Error al buscar path Repo.\n");
		return 0;
	}		

	alltrim(sPathRepo, ' ');
	strcat(sPathRepo, "data_out/");
		
	return 1;
}

short ArchivoValido(sArchivo)
char	*sArchivo;
{
	char	sMascara[30];
	char	*sSubCadena;
	int	iLargo;
	
	memset(sMascara, '\0', sizeof(sMascara));
	
	strcpy(sMascara, "enel_care_case_efactura_t1_");

	alltrim(sArchivo, ' ');
	
	if (strcmp(sArchivo, ".")  == 0 || strcmp(sArchivo, "..") == 0){
		return 0;
	}

	iLargo=strlen(sArchivo);
	if(iLargo != 39){
		return 0;
	}
	sSubCadena = substring(sArchivo, 1, 27);
	/*alltrim(sSubCadena, ' ');*/

	if( strcmp(sSubCadena, sMascara)!= 0){
		return 0;
	}

	return 1;
}


short AbreArchivos(sArchivoTrab, sPathFileTrab)
char sArchivoTrab[100];
char sPathFileTrab[200];
{
	
	memset(sSoloArchivoLog,'\0',sizeof(sSoloArchivoLog));
	memset(sArchivoLog,'\0',sizeof(sArchivoLog));
	sprintf(sSoloArchivoLog, "%s.log", sArchivoTrab);
	sprintf(sArchivoLog, "%s%s", sPathLog, sSoloArchivoLog);
	
	pFileEntrada=fopen(sPathFileTrab, "r");
	if(! pFileEntrada){
		printf("ERROR al abrir archivo trabajo %s.\n", sPathFileTrab );
		return 0;
	}
	
	pFileLog=fopen( sArchivoLog, "w" );
	if( !pFileLog ){
		printf("ERROR al abrir archivo de log %s.\n", sArchivoLog );
		return 0;
	}

	return 1;	
}


void CerrarArchivos(void){
	fclose(pFileEntrada);
	fclose(pFileLog);
}


short ProcesaArchivo(){
char				sLinea[1000];
$ClsEfactura	reg;
long   			iLinea;

	fgets(sLinea, 1000, pFileEntrada);
	iLinea=0;
	while (!feof(pFileEntrada)){
		if(iLinea > 0){
			clientesProcesados++;
			CargaRegistro( sLinea, &reg);
			
			/*printf("Cliente: %ld  correos:%s M1:[%s] M2:[%s] M3:[%s]\n", reg.cuentaContrato, reg.email, reg.email_1, reg.email_2, reg.email_3);*/

			if(ValidoRegistro(reg)){
				if(reg.iAccion==1){
					/* Proceso el alta */
					if(!ProcesaAlta(reg)){
						clientesRechazados++;
					}
				}else{
					/* Proceso la baja */
					if(!ProcesaBaja(reg)){
						clientesRechazados++;
					}				
				}
				
			}else{
				clientesRechazados++;
			}

		}
		fgets(sLinea, 1000, pFileEntrada);
		iLinea++;
	}
	
	return 1;
}

void CargaRegistro( sLinea, reg)
char				sLinea[1000];
$ClsEfactura	*reg;
{
	/*char 	sCampo[100];*/
	int	iRcv;
	int	i;
	char *sCampo;
	
	InicializoRegistro(reg);
	
	sCampo=strtok(sLinea, "|");
	i=1;
	
	while(sCampo){
		switch(i){
			case 1:
				strcpy(reg->codEmpresa, sCampo);
				break;
			case 2:
				reg->cuentaContrato = atol(sCampo);
				break;
			case 3:
				strcpy(reg->email, sCampo);
				break;
			case 4:
				strcpy(reg->estado, sCampo);
				break;
			case 5:
				strcpy(reg->externalID, sCampo);
				break;
			case 6:
				strcpy(reg->rolModif, sCampo);
				break;
			case 7:
				strcpy(reg->fechaModif, sCampo);
				break;
			case 8:
				strcpy(reg->tipoReparto, sCampo);
				break;
			
		}
		sCampo=strtok(NULL, "|");
		i++;
	}
	alltrim(reg->email, ' ');
	
	if(strcmp(reg->email, "false")==0){
		
		strcpy(reg->email, "");
		strcpy(reg->estado, "false");
	}
	
	if(strcmp(reg->email, "")!=0){
		sCampo=strtok(reg->email, ";");
		i=1;
		while(sCampo){
			switch(i){
				case 1:
					strcpy(reg->email_1, sCampo);
					break;
				case 2:
					strcpy(reg->email_2, sCampo);
					break;
				case 3:
					strcpy(reg->email_3, sCampo);
					break;			
			}
			sCampo=strtok(NULL, ";");
			i++;
		}
	}

	if(strcmp(reg->estado, "true")==0 || strcmp(reg->estado, "True")==0 || strcmp(reg->estado, "TRUE")==0){
		reg->iAccion = 1;
	}else{
		reg->iAccion = 0;
	}
	
}

void InicializoRegistro(reg)
$ClsEfactura	*reg;
{
	memset(reg->codEmpresa, '\0', sizeof(reg->codEmpresa));
	rsetnull(CLONGTYPE, (char *) &(reg->cuentaContrato));
	memset(reg->email, '\0', sizeof(reg->email));	
	memset(reg->estado, '\0', sizeof(reg->estado));	
	memset(reg->externalID, '\0', sizeof(reg->externalID));	
	memset(reg->rolModif, '\0', sizeof(reg->rolModif));	
	memset(reg->fechaModif, '\0', sizeof(reg->fechaModif));	
	memset(reg->tipoReparto, '\0', sizeof(reg->tipoReparto));	
	memset(reg->email_1, '\0', sizeof(reg->email_1));	
	memset(reg->email_2, '\0', sizeof(reg->email_2));	
	memset(reg->email_3, '\0', sizeof(reg->email_3));
	rsetnull(CINTTYPE, (char *) &(reg->iAccion));
}

short ValidoRegistro(reg)
$ClsEfactura	reg;
{
	char sLineaLog[1000];
	int  iRcv;
	$int	iEstado;
	$char	sRol[20];
	$char sPapel[2];
	
	memset(sLineaLog, '\0', sizeof(sLineaLog));
	
	alltrim(reg.estado, ' ');
	alltrim(reg.email, ' ');
	alltrim(reg.email_1, ' ');
	alltrim(reg.email_2, ' ');
	alltrim(reg.email_3, ' ');
	
	if(reg.iAccion==1 && strcmp(reg.email, "")==0){
		sprintf(sLineaLog, "ERROR - CuentaContrato %ld - Alta EFactura sin emails.\n", reg.cuentaContrato);
		iRcv=fprintf(pFileLog, sLineaLog);
		if(iRcv < 0){
			printf("Error al escribir log\n");
			exit(1);
		}
		return 0;
	}

	if(strcmp(reg.email_1, "")){
		if(!ValidaEmail(reg.email_1)){
			sprintf(sLineaLog, "ERROR - CuentaContrato %ld - Email 1 Invalido.\n", reg.cuentaContrato);
			iRcv=fprintf(pFileLog, sLineaLog);
			if(iRcv < 0){
				printf("Error al escribir log\n");
				exit(1);
			}
			return 0;			
		}
	}

	if(strcmp(reg.email_2, "")){
		if(!ValidaEmail(reg.email_2)){
			sprintf(sLineaLog, "ERROR - CuentaContrato %ld - Email 2 Invalido.\n", reg.cuentaContrato);
			iRcv=fprintf(pFileLog, sLineaLog);
			if(iRcv < 0){
				printf("Error al escribir log\n");
				exit(1);
			}
			return 0;			
		}
	}

	if(strcmp(reg.email_3, "")){
		if(!ValidaEmail(reg.email_3)){
			sprintf(sLineaLog, "ERROR - CuentaContrato %ld - Email 3 Invalido.\n", reg.cuentaContrato);
			iRcv=fprintf(pFileLog, sLineaLog);
			if(iRcv < 0){
				printf("Error al escribir log\n");
				exit(1);
			}
			return 0;			
		}
	}
	
	$EXECUTE stsCliente INTO :iEstado, :sRol, :sPapel USING :reg.cuentaContrato;
	
	if(SQLCODE != 0){
		if(SQLCODE == 100){
			sprintf(sLineaLog, "ERROR - CuentaContrato %ld - El cliente no existe en T1.\n", reg.cuentaContrato);
			iRcv=fprintf(pFileLog, sLineaLog);
			if(iRcv < 0){
				printf("Error al escribir log\n");
				exit(1);
			}
			return 0;			
		}else{
			sprintf(sLineaLog, "ERROR - CuentaContrato %ld - No se pudo validar existencia cliente.\n", reg.cuentaContrato);
			iRcv=fprintf(pFileLog, sLineaLog);
			if(iRcv < 0){
				printf("Error al escribir log\n");
				exit(1);
			}
			return 0;			
		}
	}
	
	if(iEstado != 0){
		sprintf(sLineaLog, "ERROR - CuentaContrato %ld - Cliente NO ACTIVO.\n", reg.cuentaContrato);
		iRcv=fprintf(pFileLog, sLineaLog);
		if(iRcv < 0){
			printf("Error al escribir log\n");
			exit(1);
		}
		return 0;
	}
	
	alltrim(sRol, ' ');
	if(strcmp(sRol, "")){
		iExisteDebito=1;
	}else{
		iExisteDebito=0;
	}
	
	return 1;
}

short ProcesaAlta(reg)
$ClsEfactura reg;
{
	char	sLineaLog[1000];
	int 	iRcv;
	$char	sDatoNuevo[60];
	$char sDatoAnterior[60];
	
	memset(sLineaLog, '\0', sizeof(sLineaLog));
	memset(sDatoNuevo, '\0', sizeof(sDatoNuevo));
	memset(sDatoAnterior, '\0', sizeof(sDatoAnterior));
	
	$BEGIN WORK;
	
	if(iExisteDebito){
		/* UPDATE */
		strcpy(sDatoAnterior, "MODIFICO VALORES");
		strcpy(sDatoNuevo, reg.email);
		
		$EXECUTE updDebito USING :reg.email_1,
			:reg.email_2,
			:reg.email_3,
			:reg.tipoReparto,
			:reg.cuentaContrato;
			
		if(SQLCODE != 0){
			sprintf(sLineaLog, "ERROR - CuentaContrato %ld - No se pudo actualizar los datos.\n", reg.cuentaContrato);
			iRcv=fprintf(pFileLog, sLineaLog);
			if(iRcv < 0){
				printf("Error al escribir log\n");
				exit(1);
			}			
			$ROLLBACK WORK;
			return 0;
		}
		
	}else{
		/* INSERT */
		strcpy(sDatoAnterior, "NO TENIA");
		strcpy(sDatoNuevo, reg.email);
				
		$EXECUTE insDebito USING :reg.cuentaContrato,
			:reg.email_1,
			:reg.email_2,
			:reg.email_3,
			:reg.tipoReparto;
			
		if(SQLCODE != 0){
			sprintf(sLineaLog, "ERROR - CuentaContrato %ld - No se pudo grabar los datos.\n", reg.cuentaContrato);
			iRcv=fprintf(pFileLog, sLineaLog);
			if(iRcv < 0){
				printf("Error al escribir log\n");
				exit(1);
			}			
			$ROLLBACK WORK;
			return 0;
		}		
	}

	$EXECUTE insModif USING :reg.cuentaContrato,
		:sDatoAnterior,
		:sDatoNuevo;
	
	if(SQLCODE != 0){
		sprintf(sLineaLog, "ERROR - CuentaContrato %ld - No se pudo grabar en modif.\n", reg.cuentaContrato);
		iRcv=fprintf(pFileLog, sLineaLog);
		if(iRcv < 0){
			printf("Error al escribir log\n");
			exit(1);
		}		
		$ROLLBACK WORK;
		return 0;
	}

	$COMMIT WORK;
	
	return 1;
}

short ProcesaBaja(reg)
$ClsEfactura reg;
{
	char	sLineaLog[1000];
	int 	iRcv;
	$char	sDatoNuevo[60];
	$char sDatoAnterior[60];
	
	memset(sLineaLog, '\0', sizeof(sLineaLog));
	memset(sDatoNuevo, '\0', sizeof(sDatoNuevo));
	memset(sDatoAnterior, '\0', sizeof(sDatoAnterior));
	strcpy(sDatoNuevo, "BAJA");

	if(! iExisteDebito){
		sprintf(sLineaLog, "ERROR - CuentaContrato %ld - Se solicitó baja de cliente NO adherido.\n", reg.cuentaContrato);
		iRcv=fprintf(pFileLog, sLineaLog);
		if(iRcv < 0){
			printf("Error al escribir log\n");
			exit(1);
		}
		return 0;
	}

	$BEGIN WORK;
	
	$EXECUTE delDebito USING :reg.cuentaContrato;
	
	if(SQLCODE != 0){
		sprintf(sLineaLog, "ERROR - CuentaContrato %ld - No se pudo actualizar los datos.\n", reg.cuentaContrato);
		iRcv=fprintf(pFileLog, sLineaLog);
		if(iRcv < 0){
			printf("Error al escribir log\n");
			exit(1);
		}			
		$ROLLBACK WORK;
		return 0;
	}

	$EXECUTE insModif USING :reg.cuentaContrato,
		:sDatoAnterior,
		:sDatoNuevo;
	
	if(SQLCODE != 0){
		sprintf(sLineaLog, "ERROR - CuentaContrato %ld - No se pudo grabar en modif.\n", reg.cuentaContrato);
		iRcv=fprintf(pFileLog, sLineaLog);
		if(iRcv < 0){
			printf("Error al escribir log\n");
			exit(1);
		}		
		$ROLLBACK WORK;
		return 0;
	}

	$COMMIT WORK;
	
	return 1;
}

short ValidaEmail(eMail)
char    *eMail;
{
    int     i, j, s;
    int     largo=0;
    int     valor=0;
    char    *sResu;
    int     iPos;
    int     iAsc;

    largo=strlen(eMail);
    iPos=0;
    if(largo<=0){
        return 0;
    }

    /* Que no tenga caracteres inválidos */
    valor=0;
    i=0;
    s=0;

    while(i<largo && s==0){
        iAsc=eMail[i];

        if(iAsc >= 1 && iAsc < 45){
            s=1;
        }

        if(iAsc==47)
            s=1;

        if(iAsc >= 58 && iAsc <= 63){
            s=1;
        }

        if(iAsc >= 91 && iAsc <= 96 && iAsc != 95){
            s=1;
        }

        if(iAsc >= 126 && iAsc <= 255){
            s=1;
        }

        i++;

    }

    if(s==1){
        return 0;
   }

    /* Que no termine en punto */
    if(eMail[largo-1]=='.'){
        return 0;
    }


    /* Que solo tenga una @ */
    valor=instr(eMail, "@");
    if(valor != 1){
        return 0;
    }

    /* Que tenga al menos un punto */
    valor=instr(eMail, ".");
    if(valor < 1){
        return 0;
    }

    /* Que no tenga '..' */
    if(strstr(eMail, "..") != NULL){
        return 0;
    }

    /* Que no tenga '.@' */
    if(strstr(eMail, ".@") != NULL){
        return 0;
    }

    /* Que no tenga '@.' */
    if(strstr(eMail, "@.") != NULL){
        return 0;
    }

    return 1;
}


/*
void FormateaArchivos(void){
char	sCommand[1000];
int		iRcv, i;
char	sPathCp[100];

	memset(sCommand, '\0', sizeof(sCommand));
	memset(sPathCp, '\0', sizeof(sPathCp));

    if(giEstadoCliente==0){

       sprintf(sPathCp, "%sActivos/", sPathCopia);
	}else{

       sprintf(sPathCp, "%sInactivos/", sPathCopia);
	}

	sprintf(sCommand, "chmod 755 %s", sArchDepgarUnx);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchDepgarUnx, sPathCp);
	iRcv=system(sCommand);
   
   if(iRcv==0){
      sprintf(sCommand, "rm -f %s", sArchDepgarUnx);
      iRcv=system(sCommand);
   }
   
}
*/

void CreaPrepare(void){
$char sql[10000];
$char sAux[1000];

	memset(sql, '\0', sizeof(sql));
	memset(sAux, '\0', sizeof(sAux));
	
	/******** Fecha Actual Formateada ****************/
	strcpy(sql, "SELECT TO_CHAR(TODAY, '%Y%m%d') FROM dual ");
	
	$PREPARE selFechaActualFmt FROM $sql;

	/******** Fecha Actual  ****************/
	strcpy(sql, "SELECT TO_CHAR(TODAY, '%d/%m/%Y') FROM dual ");
	
	$PREPARE selFechaActual FROM $sql;	
	
	/***************** Rutas Archivos ****************/
	$PREPARE selRutaIn FROM "SELECT valor_alf FROM tabla
		WHERE nomtabla = 'PATH'
		AND sucursal = '0000'
		AND codigo = 'SLTIN'
		AND fecha_activacion <= TODAY
		AND (fecha_desactivac IS NULL OR fecha_desactivac > TODAY)";

	$PREPARE selRutaLog FROM "SELECT valor_alf FROM tabla
		WHERE nomtabla = 'PATH'
		AND sucursal = '0000'
		AND codigo = 'SLTLOG'
		AND fecha_activacion <= TODAY
		AND (fecha_desactivac IS NULL OR fecha_desactivac > TODAY)";

	$PREPARE selRutaMalos FROM "SELECT valor_alf FROM tabla
		WHERE nomtabla = 'PATH'
		AND sucursal = '0000'
		AND codigo = 'SLTBAD'
		AND fecha_activacion <= TODAY
		AND (fecha_desactivac IS NULL OR fecha_desactivac > TODAY)";

	$PREPARE selRutaOut FROM "SELECT valor_alf FROM tabla
		WHERE nomtabla = 'PATH'
		AND sucursal = '0000'
		AND codigo = 'SLTOUT'
		AND fecha_activacion <= TODAY
		AND (fecha_desactivac IS NULL OR fecha_desactivac > TODAY)";	
	
	/************* Valido Cliente ***************/
	$PREPARE stsCliente FROM "SELECT c.estado_cliente, d.rol_creador, d.sin_papel
		FROM cliente c, OUTER clientes_digital d
		WHERE c.numero_cliente = ?
		AND d.numero_cliente = c.numero_cliente
		AND fecha_alta <= CURRENT
		AND (fecha_baja IS NULL OR fecha_baja > CURRENT) ";
	
	/************ Update Debito *************/
	$PREPARE updDebito FROM "UPDATE clientes_digital SET
		email_1 = ?,
		email_2 = ?,
		email_3 = ?,
		sin_papel = ?,
		rol_modif = 'SALESFORCE',
		fecha_modif = CURRENT
		WHERE numero_cliente = ?
		AND fecha_alta <= CURRENT
		AND (fecha_baja IS NULL OR fecha_baja > CURRENT) ";
		
	/********** Insert Debito ***********/
	$PREPARE insDebito FROM "INSERT INTO clientes_digital(
		numero_cliente,
		email_1,
		email_2,
		email_3,
		sin_papel,
		rol_creador,
		fecha_alta
		)VALUES( ?, ?, ?, ?, ?, 'SALESFORCE', CURRENT) ";

	/*********** Baja debito ***********/
	$PREPARE delDebito FROM "UPDATE clientes_digital SET
            rol_baja = 'SALESFORCE',
            fecha_baja = CURRENT
            WHERE numero_cliente = ? 
            AND fecha_alta <= TODAY 
            AND (fecha_baja IS NULL OR fecha_baja > TODAY) ";

	/********** Insert Modif **********/
	$PREPARE insModif FROM "INSERT INTO modif (
		numero_cliente,
		tipo_orden,
		ficha,
		fecha_modif,
		tipo_cliente,
		codigo_modif,
		dato_anterior,
		dato_nuevo,
		proced,
		dir_ip
		)VALUES(
		?, 'MOD', 'SALESFORCE', CURRENT, 'A', 269, ?, ?, 'FUSE_BATCH', 'BATCH')	";
	
	
}

/*
void InicializaDepgar(regDep)
$ClsDepgar	*regDep;
{

   rsetnull(CLONGTYPE, (char *) &(regDep->numero_dg));
   rsetnull(CLONGTYPE, (char *) &(regDep->numero_cliente));
   memset(regDep->sFechaDeposito, '\0', sizeof(regDep->sFechaDeposito));
   rsetnull(CLONGTYPE, (char *) &(regDep->lFechaDeposito));
   memset(regDep->sFechaReintegro, '\0', sizeof(regDep->sFechaReintegro));
   rsetnull(CDOUBLETYPE, (char *) &(regDep->valor_deposito));
   memset(regDep->estado, '\0', sizeof(regDep->estado));
   memset(regDep->estado_dg, '\0', sizeof(regDep->estado_dg));
   memset(regDep->origen, '\0', sizeof(regDep->origen));  
   memset(regDep->motivo, '\0', sizeof(regDep->motivo));
   rsetnull(CLONGTYPE, (char *) &(regDep->garante));
   memset(regDep->sFechaVigTarifa, '\0', sizeof(regDep->sFechaVigTarifa));
   rsetnull(CLONGTYPE, (char *) &(regDep->lFechaVigTarifa));
   
   rsetnull(CLONGTYPE, (char *) &(regDep->lFechaReintegro));
   rsetnull(CLONGTYPE, (char *) &(regDep->numero_comprob));

}
*/







/****************************
		GENERALES
*****************************/

void command(cmd,buff_cmd)
char *cmd;
char *buff_cmd;
{
   FILE *pf;
   char *p_aux;
   pf =  popen(cmd, "r");
   if (pf == NULL)
       strcpy(buff_cmd, "E   Error en ejecucion del comando");
   else
       {
       strcpy(buff_cmd,"\n");
       while (fgets(buff_cmd + strlen(buff_cmd),512,pf))
           if (strlen(buff_cmd) > 5000)
              break;
       }
   p_aux = buff_cmd;
   *(p_aux + strlen(buff_cmd) + 1) = 0;
   pclose(pf);
}


char *strReplace(sCadena, cFind, cRemp)
char sCadena[1000];
char cFind[2];
char cRemp[2];
{
	char sNvaCadena[1000];
	int lLargo;
	int lPos;
	int dPos=0;
	
	lLargo=strlen(sCadena);

	for(lPos=0; lPos<lLargo; lPos++){

		if(sCadena[lPos]!= cFind[0]){
			sNvaCadena[dPos]=sCadena[lPos];
			dPos++;
		}else{
			if(strcmp(cRemp, "")!=0){
				sNvaCadena[dPos]=cRemp[0];	
				dPos++;
			}
		}
	}
	
	sNvaCadena[dPos]='\0';

	return sNvaCadena;
}

char *substring(char *string, int position, int length)
{
   char *pointer;
   int c;
 
   pointer = malloc(length+1);
   
   if (pointer == NULL)
   {
      printf("Unable to allocate memory.\n");
      exit(1);
   }
 
   for (c = 0 ; c < length ; c++)
   {
      *(pointer+c) = *(string+position-1);      
      string++;  
   }
 
   *(pointer+c) = '\0';
 
   return pointer;
}

int instr(cadena, patron)
char  *cadena;
char  *patron;
{
   int valor=0;
   int i;
   int largo;
   
   largo = strlen(cadena);
   
   for(i=0; i<largo; i++){
      if(cadena[i]==patron[0])
         valor++;
   }
   return valor;
}


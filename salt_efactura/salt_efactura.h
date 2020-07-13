$ifndef SALTEFACTURA_H;
$define SALTEFACTURA_H;

#include "ustring.h"
#include "macmath.h"

$include sqltypes.h;
$include sqlerror.h;
$include datetime.h;

#define BORRAR(x)       memset(&x, 0, sizeof x)
#define BORRA_STR(str)  memset(str, 0, sizeof str)


/* Estructuras **/

$typedef struct{
    char		codEmpresa[5];
    long    cuentaContrato;
    char		email[300];
    char		estado[10];
    char		externalID[20];
    char		rolModif[20];
    char		fechaModif[20];
    char		tipoReparto[2];

    char		email_1[50];
    char		email_2[50];
    char		email_3[50];
    
    int		iAccion;
}ClsEfactura;

/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short CargarPaths(void);
short ArchivoValido(char*);
short ProcesaArchivo(void);
void	CargaRegistro( char *, ClsEfactura *);
void	InicializoRegistro(ClsEfactura *);
short ValidoRegistro(ClsEfactura);
short ValidaEmail(char *);
short ProcesaAlta(ClsEfactura);
short ProcesaBaja(ClsEfactura);

short	AbreArchivos(char *, char *);
void  CreaPrepare(void);
char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);

char *substring(char *, int, int);
int  instr(char *, char *);

$endif;

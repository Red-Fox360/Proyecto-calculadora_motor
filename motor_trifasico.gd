extends Control
class_name Motor_electrico
@export var Salida_texto:RichTextLabel
@export var Selection_tab:TabContainer
var errores: int = 0

@onready var Verificar_caso_1:Dictionary = {"Carga":Carga, "Velocidad":Velocidad
	, "Voltaje estrella":Voltaje_estrella, "Voltaje triangulo":Voltaje_triangulo
	, "Par de polos":Par_polos, "HP":HP} # Verificar lineas de texto del caso 1

#region / variables del caso 1
@export var Carga:LineEdit # Kg carga
@export var Velocidad:LineEdit # Velocidad metros por segundo (ms)

var Voltaje:int # Voltaje fuente
var Frecuencia:int # Frecuencia fuente

@export var Voltaje_estrella:LineEdit
@export var Voltaje_triangulo:LineEdit
@export var Par_polos:LineEdit
@export var HP:LineEdit

var lista_valores_1:Array = []
#endregion

#region / variables del caso 2

#endregion

#region / variables de calculos
var v_linea:int = 380
var frec:int = 50
enum Conexion {Con_est, Con_tri} # Determinar el tipo de conexion
const Incompatible = -1
const HP_A_W := 745.7
const G = 9.81 # Gravedad
const EF_TRANSM := 0.9              # tambor + reductor
const COS_PHI := 0.85
const EF_MOTOR := 0.85
const DESLIZAMIENTO := 0.04
var Po_necesaria_w:float
var Po_necesaria_hp:float

var calculo_ok := false
var mensaje_error := ""
var caso_actual := 0                # 1 o 2

# Ambos casos
var vel_deseada_ms := 0.0
var p_necesaria_w := 0.0
var p_necesaria_hp := 0.0
var i_linea_a := 0.0
var rpm_real := 0.0
var torque_nm := 0.0
var v_fase_estrella_v := 0.0
var i_fase_estrella_a := 0.0
var v_fase_triangulo_v := 0.0
var i_fase_triangulo_a := 0.0

# Solo caso 1
var cumple := false
var p_motor_w := 0.0
var carga_pct := 0.0                # % de la potencia del motor que usa la carga
var v_max_ms := 0.0
var conexion_texto := ""
var v_fase_v := 0.0                 # voltaje por bobina en la conexión elegida
var i_fase_a := 0.0  
#endregion

func _ready():
	pass

func _on_botoncalculo_pressed() -> void:
	var Current_selection = Selection_tab.current_tab
	if Current_selection == 0:
		Salida_texto.newline()
		Salida_texto.add_text("///===///")
		Salida_texto.newline()
		for i in Verificar_caso_1:
			var valor:String = Verificar_caso_1[i].text.strip_edges()
			if valor.is_empty():
				Salida_texto.add_text("Error /// %s : Sin asignar\n" % i)
				errores += 1
			elif !valor.is_valid_float():
				Salida_texto.add_text("Error /// %s : Valor no numérico : (%s)\n" % [i, valor])
				errores += 1
			else:
				lista_valores_1.append([i, valor.to_float()])
				Salida_texto.add_text("%s : %s\n" % [i, valor.to_float()])
		if errores != 0:
			Salida_texto.add_text(" /// Datos no validos: %d" % errores)
			errores = 0
			Asignar_valores()
	else:
		pass

func Asignar_valores():
	var ca
	var ve
	var v_es
	var v_tr
	var pp
	var h_p
	for i in lista_valores_1:
		match i[0]:
			"Carga": 
				ca = i[1]
			"Velocidad":
				ve = i[1]
			"Voltaje estrella":
				v_es = i[1]
			"Voltaje triangulo":
				v_tr = i[1]
			"Par de polos":
				pp = i[1]
			"HP":
				h_p = i[1]
			_:
				Salida_texto.newline()
				Salida_texto.add_text("Error /// Valores")
				break
		print(typeof(ca))
		Calculos_caso1(ca, ve, h_p, v_tr, v_es, v_linea, frec, pp)
func _on_boton_limpiar_datos_pressed() -> void:
	pass # Replace with function body.

func _on_botonlimpiar_salida_pressed() -> void:
	Salida_texto.clear()

func Calculos_caso1(Masa_kg:float, Vel_ms:float, hp_motor:float, V_tri:float,
	V_est:float, V_linea:float, Frec:float, Pares_polos:int):
	var conex = Verificar_conexiones(V_linea,V_est, V_tri)
	if conex == Incompatible:
		Salida_texto.newline()
		Salida_texto.add_text("Error /// El motor no es compatible con la red electrica")
		return false
	Po_necesaria_w = Potencia_necesaria(Masa_kg, Vel_ms)
	Po_necesaria_hp = Po_necesaria_w / HP_A_W
	p_motor_w = hp_motor * HP_A_W
	carga_pct = Po_necesaria_w / p_motor_w * 100
	cumple = p_necesaria_w <= p_motor_w
	v_max_ms = velocidad_maxima_ms(p_motor_w, Masa_kg)
	
	conexion_texto = nombre_conexion(conex)
	_calcular_electrico(p_motor_w, V_linea, Frec, Pares_polos)
	if conex == Conexion.Con_est:
		v_fase_v = v_fase_estrella_v
		i_fase_a = i_fase_estrella_a
	else:
		v_fase_v = v_fase_triangulo_v
		i_fase_a = i_fase_triangulo_a
	
	calculo_ok = true
	return true

func Verificar_conexiones(Volt_linea:float, Volt_est:float, Volt_tri:float):
	if absf(( Volt_linea - Volt_tri) / Volt_tri <= 0.05):
		print("tri: ",( Volt_linea - Volt_tri) / Volt_tri)
		return Conexion.Con_tri
	if absf((Volt_linea - Volt_est) / Volt_est <= 0.05):
		print("est: ",(Volt_linea - Volt_est) / Volt_est)
		return Conexion.Con_est
	return Incompatible

func Potencia_necesaria(masa_kg:float, vel_ms:float):
	return masa_kg * G * vel_ms / EF_TRANSM

func velocidad_maxima_ms(p_motor: float, masa_kg: float) -> float:
	return p_motor * EF_TRANSM / (masa_kg * G)

func nombre_conexion(conexion: int) -> String:
	return "Estrella" if conexion == Conexion.Con_est else "Triángulo"

func _calcular_electrico(p_salida_w: float, v_l: float, frecuencia: float,
		pares_polos: int) -> void:
	var i_linea = (p_salida_w / EF_MOTOR) / (sqrt(3) * v_linea * COS_PHI)
	i_linea_a = i_linea
	v_fase_estrella_v = v_l / sqrt(3)
	i_fase_estrella_a = i_linea
	v_fase_triangulo_v = v_l
	i_fase_triangulo_a = i_linea / sqrt(3)

	var rpm_sinc = 60.0 * frecuencia / pares_polos
	rpm_real = rpm_sinc * (1.0 - DESLIZAMIENTO)
	torque_nm = p_salida_w / (rpm_real * TAU / 60.0)

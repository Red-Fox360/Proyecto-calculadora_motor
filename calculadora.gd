class_name Calculos
extends Node

# ============================================================
# INICIO: CONSTANTES Y TIPOS
# ============================================================
const HP_A_W := 745.7
const G := 9.81

# Valores estimados típicos (no medidos)
const EF_TRANSM := 0.9              # tambor + reductor
const COS_PHI := 0.85
const EF_MOTOR := 0.85
const DESLIZAMIENTO := 0.04
const TOLERANCIA_VOLTAJE := 0.05    # 5 % de diferencia aceptada con la placa

enum Conexion { ESTRELLA, TRIANGULO }
const INCOMPATIBLE := -1
# ============================================================
# FIN: CONSTANTES Y TIPOS
# ============================================================


# ============================================================
# INICIO: VARIABLES DE RESULTADOS
# (guardan los resultados del último cálculo)
# ============================================================
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
var i_fase_a := 0.0                 # corriente por bobina en la conexión elegida

func limpiar_resultados() -> void:
	calculo_ok = false
	mensaje_error = ""
	caso_actual = 0
	vel_deseada_ms = 0.0
	p_necesaria_w = 0.0
	p_necesaria_hp = 0.0
	i_linea_a = 0.0
	rpm_real = 0.0
	torque_nm = 0.0
	v_fase_estrella_v = 0.0
	i_fase_estrella_a = 0.0
	v_fase_triangulo_v = 0.0
	i_fase_triangulo_a = 0.0
	cumple = false
	p_motor_w = 0.0
	carga_pct = 0.0
	v_max_ms = 0.0
	conexion_texto = ""
	v_fase_v = 0.0
	i_fase_a = 0.0
# ============================================================
# FIN: VARIABLES DE RESULTADOS
# ============================================================


# ============================================================
# INICIO: VALIDACIONES
# (devuelven "" si todo está bien, o el mensaje de error)
# ============================================================
func validar_carga(masa_kg: float, vel_ms: float) -> String:
	if masa_kg <= 0.0:
		return "La masa debe ser mayor que 0."
	if vel_ms <= 0.0:
		return "La velocidad debe ser mayor que 0."
	return ""

func validar_red(v_linea: float, frecuencia: float, pares_polos: int) -> String:
	if v_linea <= 0.0:
		return "El voltaje de la red debe ser mayor que 0."
	if frecuencia <= 0.0:
		return "La frecuencia debe ser mayor que 0."
	if pares_polos < 1:
		return "Los pares de polos deben ser al menos 1."
	return ""
# ============================================================
# FIN: VALIDACIONES
# ============================================================


# ============================================================
# INICIO: FÓRMULAS (potencia, velocidad, eléctrico, conexión)
# ============================================================
# Potencia que exige mover la carga (motor al 100 %, sin márgenes)
func potencia_necesaria_w(masa_kg: float, vel_ms: float) -> float:
	return masa_kg * G * vel_ms / EF_TRANSM

# Velocidad máxima a la que ese motor mueve la carga
func velocidad_maxima_ms(p_motor: float, masa_kg: float) -> float:
	return p_motor * EF_TRANSM / (masa_kg * G)

# Guarda corriente, rpm, torque y valores por bobina de ambas conexiones
func _calcular_electrico(p_salida_w: float, v_linea: float, frecuencia: float,
		pares_polos: int) -> void:
	var i_linea = (p_salida_w / EF_MOTOR) / (sqrt(3) * v_linea * COS_PHI)
	i_linea_a = i_linea
	v_fase_estrella_v = v_linea / sqrt(3)
	i_fase_estrella_a = i_linea
	v_fase_triangulo_v = v_linea
	i_fase_triangulo_a = i_linea / sqrt(3)

	var rpm_sinc = 60.0 * frecuencia / pares_polos
	rpm_real = rpm_sinc * (1.0 - DESLIZAMIENTO)
	torque_nm = p_salida_w / (rpm_real * TAU / 60.0)

# Devuelve Conexion.ESTRELLA, Conexion.TRIANGULO o INCOMPATIBLE
func conexion_para_red(v_linea: float, v_placa_tri: float, v_placa_estr: float) -> int:
	if absf(v_linea - v_placa_tri) / v_placa_tri <= TOLERANCIA_VOLTAJE:
		return Conexion.TRIANGULO
	if absf(v_linea - v_placa_estr) / v_placa_estr <= TOLERANCIA_VOLTAJE:
		return Conexion.ESTRELLA
	return INCOMPATIBLE

func nombre_conexion(conexion: int) -> String:
	return "Estrella" if conexion == Conexion.ESTRELLA else "Triángulo"
# ============================================================
# FIN: FÓRMULAS
# ============================================================


# ============================================================
# INICIO: CASO 1 (ya tengo el motor)
# Guarda los resultados en las variables. Devuelve true si todo salió bien.
# ============================================================
func calcular_caso_1(masa_kg: float, vel_ms: float, hp: float,
		v_placa_tri: float, v_placa_estr: float, v_linea: float,
		frecuencia: float, pares_polos: int) -> bool:
	limpiar_resultados()
	caso_actual = 1

	var err = validar_carga(masa_kg, vel_ms)
	if err == "":
		err = validar_red(v_linea, frecuencia, pares_polos)
	if err == "" and hp <= 0.0:
		err = "Los HP del motor deben ser mayores que 0."
	if err == "" and (v_placa_tri <= 0.0 or v_placa_estr <= 0.0):
		err = "Los voltajes de la placa deben ser mayores que 0."
	if err != "":
		mensaje_error = err
		return false

	var conexion = conexion_para_red(v_linea, v_placa_tri, v_placa_estr)
	if conexion == INCOMPATIBLE:
		mensaje_error = "El motor (%s/%s V) no es compatible con una red de %s V." \
			% [v_placa_tri, v_placa_estr, v_linea]
		return false

	vel_deseada_ms = vel_ms
	p_necesaria_w = potencia_necesaria_w(masa_kg, vel_ms)
	p_necesaria_hp = p_necesaria_w / HP_A_W
	p_motor_w = hp * HP_A_W
	carga_pct = p_necesaria_w / p_motor_w * 100.0
	cumple = p_necesaria_w <= p_motor_w
	v_max_ms = velocidad_maxima_ms(p_motor_w, masa_kg)

	conexion_texto = nombre_conexion(conexion)
	_calcular_electrico(p_motor_w, v_linea, frecuencia, pares_polos)
	if conexion == Conexion.ESTRELLA:
		v_fase_v = v_fase_estrella_v
		i_fase_a = i_fase_estrella_a
	else:
		v_fase_v = v_fase_triangulo_v
		i_fase_a = i_fase_triangulo_a

	calculo_ok = true
	return true
# ============================================================
# FIN: CASO 1
# ============================================================


# ============================================================
# INICIO: CASO 2 (no tengo el motor)
# Guarda los resultados en las variables. Devuelve true si todo salió bien.
# Muestra los valores por bobina de AMBAS conexiones: el usuario busca un
# motor cuya placa coincida con su red.
# ============================================================
func calcular_caso_2(masa_kg: float, vel_ms: float, v_linea: float,
		frecuencia: float, pares_polos: int) -> bool:
	limpiar_resultados()
	caso_actual = 2

	var err = validar_carga(masa_kg, vel_ms)
	if err == "":
		err = validar_red(v_linea, frecuencia, pares_polos)
	if err != "":
		mensaje_error = err
		return false

	vel_deseada_ms = vel_ms
	p_necesaria_w = potencia_necesaria_w(masa_kg, vel_ms)
	p_necesaria_hp = p_necesaria_w / HP_A_W
	_calcular_electrico(p_necesaria_w, v_linea, frecuencia, pares_polos)

	calculo_ok = true
	return true
# ============================================================
# FIN: CASO 2
# ============================================================

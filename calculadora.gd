extends Node
# Archivo sugerido: calculadora_motor.gd

# ============================================================
# INICIO: CONSTANTES Y TIPOS
# ============================================================
const HP_A_W := 745.7
const G := 9.81

# Eficiencias estimadas (valores típicos, no medidos)
const EF_POLEA_MEJOR := 0.98
const EF_POLEA_PEOR := 0.95
const EF_TRANSM_MEJOR := 0.95   # tambor + reductor
const EF_TRANSM_PEOR := 0.85

const ACELERACION := 0.5        # m/s²
const FACTOR_SEG := 1.25
const COS_PHI := 0.85
const EF_MOTOR := 0.85
const DESLIZAMIENTO := 0.04
const TOLERANCIA_VOLTAJE := 0.05   # 5 % de diferencia aceptada con la placa

enum Conexion { ESTRELLA, TRIANGULO }
const INCOMPATIBLE := -1
# ============================================================
# FIN: CONSTANTES Y TIPOS
# ============================================================


# ============================================================
# INICIO: VALIDACIONES
# (devuelven "" si todo está bien, o el mensaje de error)
# ============================================================
func validar_carga(masa_kg: float, vel_ms: float, n_poleas: int) -> String:
	if masa_kg <= 0.0:
		return "La masa debe ser mayor que 0."
	if vel_ms <= 0.0:
		return "La velocidad debe ser mayor que 0."
	if n_poleas < 0:
		return "El número de poleas no puede ser negativo."
	return ""

func validar_red(v_linea: float, frecuencia: float, polos: int) -> String:
	if v_linea <= 0.0:
		return "El voltaje de la red debe ser mayor que 0."
	if frecuencia <= 0.0:
		return "La frecuencia debe ser mayor que 0."
	if polos < 2 or polos % 2 != 0:
		return "Los polos deben ser un número par (2, 4, 6, 8...)."
	return ""
# ============================================================
# FIN: VALIDACIONES
# ============================================================


# ============================================================
# INICIO: CÁLCULO DE POTENCIA (rango mínima / recomendada)
# ============================================================
func _eficiencias(n_poleas: int) -> Dictionary:
	return {
		"mejor": pow(EF_POLEA_MEJOR, n_poleas) * EF_TRANSM_MEJOR,
		"peor": pow(EF_POLEA_PEOR, n_poleas) * EF_TRANSM_PEOR
	}

func rango_potencia_polea(masa_kg: float, vel_ms: float, n_poleas: int) -> Dictionary:
	var ef = _eficiencias(n_poleas)
	# Mínima: velocidad constante, mejor eficiencia, sin seguridad
	var p_min = (masa_kg * G * vel_ms) / ef["mejor"]
	# Recomendada: con aceleración, peor eficiencia y factor de seguridad
	var p_rec = (masa_kg * (G + ACELERACION) * vel_ms) / ef["peor"] * FACTOR_SEG
	return {
		"p_min_w": p_min, "p_rec_w": p_rec,
		"p_min_hp": p_min / HP_A_W, "p_rec_hp": p_rec / HP_A_W
	}
# ============================================================
# FIN: CÁLCULO DE POTENCIA
# ============================================================


# ============================================================
# INICIO: VERIFICACIÓN DEL MOTOR Y VELOCIDAD MÁXIMA
# ============================================================
func verificar_motor(hp: float, rango: Dictionary) -> String:
	var p_motor = hp * HP_A_W
	if p_motor < rango["p_min_w"]:
		return "No cumple"
	elif p_motor < rango["p_rec_w"]:
		return "Justo (sin margen)"
	return "Cumple con holgura"

func velocidad_maxima(hp: float, masa_kg: float, n_poleas: int) -> Dictionary:
	var ef = _eficiencias(n_poleas)
	var p_motor = hp * HP_A_W
	return {
		"v_limite_ms": p_motor * ef["mejor"] / (masa_kg * G),
		"v_comoda_ms": p_motor * ef["peor"] / (masa_kg * (G + ACELERACION) * FACTOR_SEG)
	}
# ============================================================
# FIN: VERIFICACIÓN DEL MOTOR Y VELOCIDAD MÁXIMA
# ============================================================


# ============================================================
# INICIO: CÁLCULO ELÉCTRICO Y CONEXIÓN
# ============================================================
func calcular_electrico(p_salida_w: float, v_linea: float, frecuencia: float,
		polos: int, conexion: int) -> Dictionary:
	var p_entrada = p_salida_w / EF_MOTOR
	var i_linea = p_entrada / (sqrt(3) * v_linea * COS_PHI)

	var v_fase: float
	var i_fase: float
	if conexion == Conexion.ESTRELLA:
		v_fase = v_linea / sqrt(3)
		i_fase = i_linea
	else:
		v_fase = v_linea
		i_fase = i_linea / sqrt(3)

	var rpm_sinc = 120.0 * frecuencia / polos
	var rpm_real = rpm_sinc * (1.0 - DESLIZAMIENTO)
	var torque = p_salida_w / (rpm_real * TAU / 60.0)

	return {
		"i_linea_a": i_linea, "v_fase_v": v_fase, "i_fase_a": i_fase,
		"rpm_sincrona": rpm_sinc, "rpm_real": rpm_real, "torque_nm": torque
	}

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
# FIN: CÁLCULO ELÉCTRICO Y CONEXIÓN
# ============================================================


# ============================================================
# INICIO: CASO 1 (ya tengo el motor)
# ============================================================
func caso_1(masa_kg: float, vel_ms: float, n_poleas: int, hp: float,
		v_placa_tri: float, v_placa_estr: float, v_linea: float,
		frecuencia: float, polos: int) -> Dictionary:
	var err = validar_carga(masa_kg, vel_ms, n_poleas)
	if err == "":
		err = validar_red(v_linea, frecuencia, polos)
	if err == "" and hp <= 0.0:
		err = "Los HP del motor deben ser mayores que 0."
	if err == "" and (v_placa_tri <= 0.0 or v_placa_estr <= 0.0):
		err = "Los voltajes de la placa deben ser mayores que 0."
	if err != "":
		return {"ok": false, "error": err}

	var conexion = conexion_para_red(v_linea, v_placa_tri, v_placa_estr)
	if conexion == INCOMPATIBLE:
		return {"ok": false, "error": "El motor (%s/%s V) no es compatible con una red de %s V." \
			% [v_placa_tri, v_placa_estr, v_linea]}

	var rango = rango_potencia_polea(masa_kg, vel_ms, n_poleas)
	return {
		"ok": true,
		"veredicto": verificar_motor(hp, rango),
		"rango": rango,
		"velocidades_max": velocidad_maxima(hp, masa_kg, n_poleas),
		"conexion": nombre_conexion(conexion),
		"electrico": calcular_electrico(hp * HP_A_W, v_linea, frecuencia, polos, conexion)
	}
# ============================================================
# FIN: CASO 1
# ============================================================


# ============================================================
# INICIO: CASO 2 (no tengo el motor)
# ============================================================
func caso_2(masa_kg: float, vel_ms: float, n_poleas: int, v_linea: float,
		frecuencia: float, polos: int, conexion: int) -> Dictionary:
	var err = validar_carga(masa_kg, vel_ms, n_poleas)
	if err == "":
		err = validar_red(v_linea, frecuencia, polos)
	if err == "" and conexion != Conexion.ESTRELLA and conexion != Conexion.TRIANGULO:
		err = "Debes elegir una conexión (estrella o triángulo)."
	if err != "":
		return {"ok": false, "error": err}

	var rango = rango_potencia_polea(masa_kg, vel_ms, n_poleas)
	return {
		"ok": true,
		"rango": rango,
		"conexion": nombre_conexion(conexion),
		# Los valores eléctricos se calculan con la potencia recomendada
		"electrico": calcular_electrico(rango["p_rec_w"], v_linea, frecuencia, polos, conexion)
	}
# ============================================================
# FIN: CASO 2
# ============================================================


# ============================================================
# INICIO: PRUEBA RÁPIDA (borrar cuando hagas la interfaz)
# ============================================================
#func _ready() -> void:
	# 100 kg, 0.5 m/s, 2 poleas, motor 2 HP 220/380 V, red 380 V, 50 Hz, 4 polos
	print(caso_1(100, 0.5, 2, 2, 220, 380, 380, 50, 4))
	print(caso_2(100, 0.5, 2, 380, 50, 4, Conexion.ESTRELLA))
# ============================================================
# FIN: PRUEBA RÁPIDA
# ============================================================

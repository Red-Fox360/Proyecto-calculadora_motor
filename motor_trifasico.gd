extends Control

@export var Salida_texto:RichTextLabel
@export var Selection_tab:TabContainer
var errores: int = 0

@onready var Verificar_caso_1:Dictionary = {"Carga":Carga, "Velocidad":Velocidad,
	"Poelas":Poleas,"Potencia":Potencia, "Voltaje estrella":Voltaje_estrella,
	"Voltaje triangulo":Voltaje_triangulo, "par de polos":Par_polos,
	"HP":HP} # Verificar lineas de texto del caso 1

#region / variables del caso 1
@export var Carga:LineEdit # Kg carga
@export var Velocidad:LineEdit # Velocidad metros por segundo (ms)
@export var Poleas:LineEdit # Cantidad de poleas

var Voltaje:int # Voltaje fuente
var Frecuencia:int # Frecuencia fuente
@export var Potencia:LineEdit # Potencia nominal del motor

@export var Voltaje_estrella:LineEdit
@export var Voltaje_triangulo:LineEdit
@export var Par_polos:LineEdit
@export var HP:LineEdit
#endregion

#region / variables del caso 2

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
				Salida_texto.add_text("%s : %s\n" % [i, valor.to_float()])
		if errores != 0:
			Salida_texto.add_text(" /// Datos no validos: %d" % errores)
			errores = 0
	else:
		pass

func _on_boton_limpiar_datos_pressed() -> void:
	pass # Replace with function body.

func _on_botonlimpiar_salida_pressed() -> void:
	Salida_texto.clear()

func Verificar_fuente():
	pass

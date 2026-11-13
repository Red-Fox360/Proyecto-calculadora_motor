extends Control

@export var Salida_texto:RichTextLabel
@export var Selection_tab:TabContainer

#region / variables del caso 1
@export var Masa:LineEdit # Kg carga
@export var Velocidad:LineEdit # Velocidad metros por segundo (ms)
@export var Poleas:LineEdit # Cantidad de poleas

@export var Voltaje:LineEdit # Voltaje fuente
@export var Frecuencia:LineEdit # Frecuencia fuente
@export var Corriente:LineEdit # Corriente maxima del motor

@export var Voltaje_estrella:LineEdit
@export var Voltaje_delta:LineEdit
@export var Par_polos:LineEdit
@export var HP:LineEdit


#endregion

var Mensaje_salida:= []

func _ready():
	pass


func _on_botoncalculo_pressed() -> void:
	var Current_selection = Selection_tab.current_tab
	var Verificar_texto_1 = [Masa.text, Velocidad.text, Poleas.text,
	Voltaje.text, Frecuencia.text, Corriente.text, Voltaje_estrella.text,
	Voltaje_delta.text, Par_polos.text, HP.text] # Verificar lineas de texto del caso 1
	if Current_selection == 0:
		for i in Verificar_texto_1:
			print(i)
			if i == "":
				Mensaje_salida.append(false)
			else:
				Mensaje_salida.append(true)
		Salida_texto.newline()
		Salida_texto.add_text(str(Mensaje_salida))
		Mensaje_salida.clear()
	else:
		pass


func _on_boton_limpiar_datos_pressed() -> void:
	pass # Replace with function body.


func _on_botonlimpiar_salida_pressed() -> void:
	Salida_texto.clear()

# High concept
“En una ciudad donde todo ruido se paga, una mensajera debe cruzar medio distrito con un pato que no
sabe estarse callado.”

Stealth-comedia con tensión física y corazón: el jugador no solo esquiva guardias, también cuida a 
un pato que reacciona al miedo, al hambre y al ruido. El disparo existe, pero es la peor solución 
elegante: resuelve un problema inmediato y genera tres nuevos.

## 1. Mundo y premisa narrativa
 ###Ciudad Murmullo
 Una metrópolis gobernada por Corporación Sshhh, que impuso el Protocolo Sshhh: impuestos al ruido, 
 zonas de silencio obligatorio, guardias acústicos y multas por estornudar en público. La empresa 
 vende “paz” a cambio de control.

 ### El pato
 Pato no es un pato cualquiera. Fue sujeto del Proyecto Quack, un experimento bioacústico. Tragó una 
 Semilla de Resonancia, un núcleo capaz de romper los campos de silencio de Sshhh. El problema: 
 cuando se estresa, grazna. Cuando tiene hambre, grazna. Cuando escucha música, grazna. Cuando ve
 una miga de pan, grazna.

 ### La protagonista
 Mara Vela, ex-ingeniera acústica de Sshhh, ahora mensajera de poca monta. Cínica, práctica y alérgica al compromiso. Su hermana Luz “DJ Bombo” dirige Radio Libre, la única emisora pirata que aún transmite música y verdad.

 ### Inciting incident
 Durante una redada, Mara recibe un encargo “simple”: entregar una jaula en Radio Libre. La jaula contiene a Pato. La redada era por él. Mara no puede devolverlo; Sshhh ya sabe que lo tiene. Ahora debe cruzar la ciudad sin que el pato haga ruido.

 ### Antagonista
 Directora Verónica Silencio, CEO de Sshhh. Cree que el ruido es violencia y que la obediencia es paz. Quiere extraer la Semilla de Resonancia de Pato para convertirla en un arma de silencio absoluto.

 ### Twist
 DJ Bombo revela que la única forma de romper el Protocolo es transmitir la frecuencia de Pato desde la Torre Sshhh. Pero la transmisión podría dañar al pato. Mara debe elegir entre la revolución y su compañero.

## 2. Cómo encaja el prototipo actual
 Prototipo actual                            Ficción
 Player movible                              Mara, mensajera acústica
 Nodo pato que emite ruido                   Pato con medidor de estrés y estados
 Guardias por waypoints que detectan sonido  Aurales, guardias con cascos direccionales
 Disparar a guardias                         Dardo sónico incapacitante: ruidoso, asusta a Pato y baja confianza
 queue_free de guardias                      El guardia queda “retirado”/evacuado; el juego lo contabiliza en stats
 Zona de finalización                        Punto de extracción de Radio Libre
 Stats de nivel                              Informe de Incidente Acústico que da DJ Bombo
 
 El disparo no debe ser “la solución”, sino fail-forward: si disparas, eliminas una patrulla, pero el ruido alerta a otros, Pato entra en pánico y pierdes confianza. Puedes terminar el nivel, pero el final y el rango cambian.

## 3. Personajes
 - Mara Vela: protagonista. Habla poco, se queja mucho. Su arco va de “solo entrego el paquete” a “esto es mi pato”.
 - Pato: coprotagonista. No habla, pero tiene estados: Calmado, Curioso, Ansioso, Pánico. Reacciona a música, disparos, guardias, snacks y cariño.
 - DJ Bombo / Luz: voz en el pinganillo. Da objetivos, humor y presión narrativa.
 - Directora Silencio: villana elegante, obsesionada con el orden. No grita nunca. Eso la hace más aterradora.
 - Inspector de Ruido: mini-boss cómico y patético, con sonar portátil.
 - El Metrónomo: boss automatizado de la emisora, un director de orquesta que convierte el ritmo en trampa.
 - Aurales: guardias. No son malvados; muchos solo necesitan el sueldo. El juego no celebra matarlos.

## 4. Progresión narrativa y de niveles
 ### Nivel 0 — “El Nido” (tutorial)
 Historia: La redada llega al edificio de Mara. Recibe a Pato de manos de un contacto que no llega a explicar nada.
 Objetivo: Escapar por el patio interior.
 Mecánicas: mover, agacharse, interactuar, susurrar para calmar a Pato.
 Pato: Calmado; primeros graznidos idle.
 Enseñanza: el ruido atrae; acariciar y mecer reducen estrés.

 ### Nivel 1 — “Callejón de las Multas”
 Historia: Mara llama a Luz. “¿Un pato? ¿En serio?” Luz solo dice: “No lo dejes graznar”.
 Objetivo: Cruzar el callejón y llegar al piso franco.
 Mecánicas: medidor de ruido, escondites, patrullas por waypoints, dardo sónico como último recurso.
 Pato: Curioso; se altera con sirenas.
 Enseñanza: disparar es ruidoso y asusta; mejor esconderse y esperar.

 ### Nivel 2 — “Mercado de Ruido”
 Historia: Sshhh cierra el mercado por “exceso de decibelios”. Mara descubre que Pato reacciona a la música de un puesto.
 Objetivo: Atravesar el mercado y recuperar el Afinador.
 Mecánicas nuevas: snacks, manta silenciadora, señuelos de goma, radios ambientales.
 Pato: Ansioso; puede entrar en pánico si hay alarmas.
 Mini-boss: Inspector de Ruido, que barre la zona con pulsos de sonar. Hay que ocultarse y calmar a Pato durante los barridos.
 Enseñanza: el ruido también puede usarse como distracción, pero siempre tiene coste.

 ### Nivel 3 — “Museo de la Quietud”
 Historia: Mara encuentra archivos del Proyecto Quack. Pato no es una mascota: es una llave.
 Objetivo: Infiltrarse en el museo y llegar a los archivos de la Torre.
 Mecánicas nuevas: salas insonorizadas, micrófonos direccionales, conductos, afinador para calmar con frecuencias concretas.
 Pato: Ansioso; empieza a graznar si Mara se aleja demasiado.
 Enseñanza: el pato es un compañero, no un objeto. La confianza importa.

 ### Nivel 4 — “Radio Libre”
 Historia: Luz revela el plan: transmitir la frecuencia de Pato para romper el Protocolo. Mara descubre que puede dañarlo.
 Objetivo: Llegar al estudio y defender la transmisión.
 Mecánicas nuevas: escolta ligera, ritmo, apagones, quack dirigido (provocar un graznido controlado por primera vez).
 Boss: El Metrónomo, un sistema de seguridad musical. Hay que sincronizar distracciones y calmar a Pato entre compases.
 Decisión narrativa: confiar en Luz o buscar una alternativa para no sacrificar a Pato.

 ### Nivel 5 — “Torre Sshhh”
 Historia: Asalto final. La Directora Silencio activa el campo de silencio absoluto.
 Objetivo: Llegar a la antena y decidir qué frecuencia transmitir.
 Mecánicas finales: campo de silencio que anula el sonido y obliga a usar el entorno; el quack dirigido se convierte en arma contra la torre.
 Boss final: Directora Silencio, que se protege con zonas mudas. Hay que crear ruido en puntos concretos sin que Pato entre en pánico total.
 Enseñanza: el clímax no es “callar al pato”, sino decidir cuándo dejarlo gritar.

## 5. Progresión de mecánicas
 Momento     Mecánica                    Función
 Tutorial    Susurrar/mecer              Calmar a Pato
 Nivel 1     Escondites + dardo sónico   Supervivencia básica
 Nivel 2     Snack, manta, señuelo       Gestión de estrés y distracciones
 Nivel 3     Afinador                    Calmar con frecuencias; puzzles acústicos
 Nivel 4     Quack dirigido              Usar el ruido del pato a propósito
 Nivel 5     Sobrecarga armónica         Usar el graznido como herramienta final

 Estados de Pato
 - Calmado: no emite ruido; obedece.
 - Curioso: emite graznidos pequeños; se distrae con música.
 - Ansioso: emite ruido medio; necesita snacks o manta.
 - Pánico: graznido fuerte; alerta a todos; solo se calma con susurro prolongado o frecuencia afinada.

 Regla de diseño
 El jugador nunca debe odiar a Pato. La tensión viene de la situación, no de castigar al animal. 
 Si el jugador dispara mucho, el juego lo refleja en confianza y finales, no en crueldad.

## 6. Stats y finales
 Al terminar cada nivel, DJ Bombo da un Informe de Incidente Acústico:

 Ruido máximo.
 Ruido total acumulado.
 Guardias incapacitados.
 Disparos realizados.
 Veces que Pato entró en pánico.
 Confianza de Pato.
 Tiempo.
 Alertas.

 ### Rangos
 S — Pato Zen: ruido mínimo, cero disparos, confianza alta.
 A — Sigilo con plumas: algún susto, controlado.
 B — Ruido controlado: disparos puntuales, algún pánico.
 C — Caos emplumado: nivel completado, pero la ciudad te oyó.

 ### Finales
 - Final Quack Libre (bueno): Mara transmite la frecuencia sin dañar a Pato. Sshhh cae. La ciudad 
 	aprende que el ruido también es vida. Pato se queda con Mara.
 - Final Silencioso (malo): Mara usa a Pato como arma. La torre cae, pero el pato pierde la Semilla 
 	y se aleja. Murmullo sigue en silencio, ahora “libre”.
 - Final Ni un Pato (secreto): completar con confianza máxima, cero disparos y cero pánicos. Mara y 
 	Pato desaparecen de la ciudad; en los créditos se oye un graznido lejano y la radio pirata vuelve a 
 	emitir.

## 7. Próximos pasos concretos en Godot
 - Añadir a Pato un medidor de estrés además del ruido.
 - Crear acciones de calma: susurrar, snack, manta, afinador.
 - Hacer que el dardo sónico emita un evento de ruido y suba estrés.
 - Convertir los waypoints en patrullas Aurales con conos de audición.
 - Implementar el Informe de Incidente Acústico al final del nivel.
 - Escribir diálogos cortos de DJ Bombo por nivel.
 - Prototipar el quack dirigido en el nivel 4 y el campo de silencio en el 5.

La historia debe servir a una idea simple: el objetivo no es callar al pato para siempre, sino
aprender cuándo merece la pena que grite.

using PyCall

# Importar Qiskit des de Python
qiskit = pyimport("qiskit")

#aer = pyimport("qiskit_aer")



# Carregar el circuit des d'un fitxer QASM
function load_qasm_circuit(filename)
    return qiskit.QuantumCircuit.from_qasm_file(filename)
end


## Adaptació dels fiters QWalk per a poder usar-los en QXZoo canviant els noms dels qubits

function replace_qasm_registers(input_file::String, output_file::String="output.qasm")
    # Llegir el contingut del fitxer
    content = read(input_file, String)

    # Crear diccionari de substitució
    replacements = Dict{String,String}()

    # Processar les definicions de registres
    node_count = 0
    coin_count = 0

    # Trobar definicions de registres
    for line in split(content, '\n')
        if occursin(r"qreg\s+node\[(\d+)\];", line)
            node_count = parse(Int, match(r"qreg\s+node\[(\d+)\];", line).captures[1])
        elseif occursin(r"qreg\s+coin\[(\d+)\];", line)
            coin_count = parse(Int, match(r"qreg\s+coin\[(\d+)\];", line).captures[1])
        end
    end

    # Generar substitució per node
    for i in 0:(node_count-1)
        replacements["node[$i]"] = "q[$i]"
    end

    # Generar substitució per coin
    for i in 0:(coin_count-1)
        replacements["coin[$i]"] = "q[$(i+node_count)]"
    end

    # Reemplaçar al contingut
    new_content = content
    for (old, new) in replacements
        new_content = replace(new_content, old => new)
    end

    # Reemplaçar la definició dels registres
    if node_count > 0 || coin_count > 0
        total_qubits = node_count + coin_count
        new_content = replace(new_content, r"qreg\s+node\[\d+\];\s*qreg\s+coin\[\d+\];" => "qreg q[$total_qubits];")
    end

    # Escriure el fitxer de sortida
    write(output_file, new_content)

    return new_content
end

## des d'un qasm obtenim un QXZoo

using QXZoo
using QXZoo.Circuit
using QXZoo.DefaultGates

function import_from_qasm(filename::String)
    # Llegir totes les línies del fitxer
    lines = readlines(filename)

    # Filtrar línies rellevants
    filtered_lines = filter(line -> !(startswith(strip(line), "//") ||
                                  startswith(strip(line), "#") ||
                                  isempty(strip(line))), lines)

    # Processar capçalera
    num_qubits = 0
    circ = nothing
    for line in filtered_lines
        if occursin(r"^qreg q\[", line)
            num_qubits = parse(Int, match(r"qreg q\[(\d+)\];", line).captures[1])
            circ = QXZoo.Circuit.Circ(num_qubits)
            break
        end
    end

    if circ === nothing
        error("No s'ha pogut determinar el nombre de qubits del fitxer QASM")
    end

    # Processar portes
    for line in filtered_lines
        if occursin(r"^[a-z]", line)
            process_gate_line!(circ, line)
        end
    end

    return circ
end





# Funció per exportar a QASM
function export_to_qasm(circ, filename)
    open(filename, "w") do f
        println(f, "OPENQASM 2.0;")
        println(f, "include \"qelib1.inc\";")
        println(f, "qreg q[", circ.num_qubits, "];")
        println(f, "creg c[", circ.num_qubits, "];")

        for gate in circ.:circ_ops

            if gate.gate_symbol.label == :x

                 println(f, "x q[",  gate.target - 1, "];") # restem si el criteri es començar de 1 en els QXTools
               # println(f, "x q[", gate.target , "];")

            elseif gate.gate_symbol.label == :y
                  println(f, "y q[",  gate.target - 1, "];") # restem si el criteri es començar de 1 en els QXTools
                #println(f, "y q[", gate.target , "];")

            elseif gate.gate_symbol.label == :z
                  println(f, "z q[",  gate.target - 1, "];") # restem si el criteri es començar de 1 en els QXTools
                #println(f, "z q[", gate.target , "];")
            elseif gate.gate_symbol.label == :h
                   println(f, "h q[", gate.target - 1, "];") # restem si el criteri es començar de 1 en els QXTools
                # println(f, "h q[", gate.target , "];")
            elseif gate.gate_symbol.label == :s
                   println(f, "s q[", gate.target - 1, "];") # restem si el criteri es començar de 1 en els QXTools
                # println(f, "s q[", gate.target , "];")
            elseif gate.gate_symbol.label == :t
                   println(f, "x q[", gate.target - 1, "];") # restem si el criteri es començar de 1 en els QXTools
                # println(f, "t q[", gate.target , "];")

            elseif gate.gate_symbol.label == :r_x    # rx(pi/2) q[1];
                println(f, "rx(",gate.gate_symbol.param ,") ","q[", gate.target - 1,"];")
                #println(f, "rx (",gate.gate_symbol.param ,") ","q[", gate.target,"];")

             elseif gate.gate_symbol.label == :r_y    # ry(pi/2) q[1];
                println(f, "ry(",gate.gate_symbol.param ,") ","q[", gate.target - 1,"];")
                # println(f, "ry (",gate.gate_symbol.param ,") ","q[", gate.target,"];")
              elseif gate.gate_symbol.label == :r_z    # rz(pi/2) q[1];
                println(f, "rz(",gate.gate_symbol.param ,") ","q[", gate.target - 1,"];")
                # println(f, "rz (",gate.gate_symbol.param ,") ","q[", gate.target,"];")
               elseif gate.gate_symbol.label == :c_x    # cx q[1], q[2];
                 # println(f, "cx ","q[",gate.ctrl,"],q[", gate.target,"];")
                  println(f, "cx ","q[",gate.ctrl-1,"],","q[", gate.target-1,"];")
                elseif gate.gate_symbol.label == :c_y    # cy q[1], q[2];
                 #println(f, "cy ","q[",gate.ctrl,"],q[", gate.target,"];")
                  println(f, "cy ","q[",gate.ctrl-1,"],","q[", gate.target-1,"];")
                elseif gate.gate_symbol.label == :c_z    # cz q[1], q[2];
                 #println(f, "cz ","q[",gate.ctrl,"],q[", gate.target,"];")
                  println(f, "cz ","q[",gate.ctrl-1,"],","q[", gate.target-1,"];")
            elseif gate.gate_symbol.label == :swap
                 println(f, "swap q[", gate.ctrl - 1, "],q[", gate.target - 1, "];")
                #println(f, "swap q[", gate.ctrl, "],q[", gate.target, "];")
            # end
            # Afegir més portes aquí si cal
              elseif gate.gate_symbol.label == :c_r_phase # cp(pi/7) q[1], q[2];
                # println(f, "cp (",gate.gate_symbol.param ,") q[",gate.ctrl,"],q[", gate.target,"];")
                println(f, "cp (",gate.gate_symbol.param ,") q[",gate.ctrl -1 ,"],q[", gate.target -1 ,"];")
            else
             @warn "Porta no suportada: $(gate.name) - Ometent"
           end
       end
    end
end



#### Afegim millores el 15 de Juliol de 2025


# aquesta funció corregix l'error que hi havia en  la penúltima versió de la funció
# En qiskit és control, target i en QXZoo a l'inrevés

function process_gate_line_vell!(circ::QXZoo.Circuit.Circ, line::String)
    try
        # Eliminar espais inicials i finals
        line = strip(line)

        # Portes d'un sol qubit no paramètriques
        if occursin(r"^x\s+q\[", line)
            qubit = parse(Int, match(r"x\s+q\[(\d+)\];", line).captures[1]) + 1
            Circuit.add_gatecall!(circ, x(qubit))

        elseif occursin(r"^y\s+q\[", line)
            qubit = parse(Int, match(r"y\s+q\[(\d+)\];", line).captures[1]) + 1
            Circuit.add_gatecall!(circ, y(qubit))

        elseif occursin(r"^z\s+q\[", line)
            qubit = parse(Int, match(r"z\s+q\[(\d+)\];", line).captures[1]) + 1
            Circuit.add_gatecall!(circ, z(qubit))

        elseif occursin(r"^h\s+q\[", line)
            qubit = parse(Int, match(r"h\s+q\[(\d+)\];", line).captures[1]) + 1
            Circuit.add_gatecall!(circ, h(qubit))

        elseif occursin(r"^s\s+q\[", line)
            qubit = parse(Int, match(r"s\s+q\[(\d+)\];", line).captures[1]) + 1
            Circuit.add_gatecall!(circ, s(qubit))

        elseif occursin(r"^t\s+q\[", line)
            qubit = parse(Int, match(r"t\s+q\[(\d+)\];", line).captures[1]) + 1
            Circuit.add_gatecall!(circ, t(qubit))

        # Portes paramètriques d'un sol qubit (sense espai després del nom)
        elseif occursin(r"^rx\(", line)
            m = match(r"rx\((.*)\)\s+q\[(\d+)\];", line)
            angle = eval(Meta.parse(m.captures[1]))  # Permet expressions com pi/2
            qubit = parse(Int, m.captures[2]) + 1
            Circuit.add_gatecall!(circ, r_x(qubit, angle))

         # afegim nous patrons de cerca per a u2 i u1
        elseif  occursin(r"^u2\(", line)
            pattern = r"u2\(([^,]+),\s*([^)]+)\)\s+q\[(\d+)\]"
            # Busca coincidències
            m = match(pattern, line)

           if m === nothing
                error("Format de línia incorrecte. S'esperava 'u2(angle1,angle2) q[qubit]'")
            end

            # Extreu i converteix els valors
            angle1_str = m.captures[1]
            angle2_str = m.captures[2]
            qubit_str = m.captures[3]

            # Analitza els angles (pot contenir expressions matemàtiques com pi/2)
           angle1 = eval(Meta.parse(angle1_str))
           angle2 = eval(Meta.parse(angle2_str))

           # Converteix el qubit a enter
            qubit = parse(Int, qubit_str) + 1
            #Ara creem la porta particular
            phi=angle1;
            lambda=angle2
            matriu = u2(phi, lambda)
            nova_porta_1q_u2=create_gate_1q("nova_porta_1q_u2", u2(phi, lambda))
            circ << u(nova_porta_1q_u2, qubit)

          # afegim nous patrons de cerca per a u2 i u1
        elseif  occursin(r"^u1\(", line)

            pattern = r"u1\(([^)]+)\)\s+q\[(\d+)\];"

            # Busca coincidències
           m = match(pattern, line)

          if m === nothing
               error("Format de línia incorrecte. S'esperava 'u1(angle) q[qubit];'")
          end

           # Extreu i converteix els valors
           angle_str = m.captures[1]
           qubit_str = m.captures[2]

          # Analitza l'angle (pot contenir expressions matemàtiques com pi/2)
           angle = eval(Meta.parse(angle_str))

           # Converteix el qubit a enter
           qubit = parse(Int, qubit_str) + 1



            #Ara creem la porta particular
            phi=angle;
            #lambda=angle2
            matriu = u1(phi)
            nova_porta_1q_u1=create_gate_1q("nova_porta_1q_u1", u1(phi))
            circ << u(nova_porta_1q_u1, qubit)

            # afegim nous patrons de cerca per a la porta p
        elseif  occursin(r"^p\(", line)

            pattern = r"p\(([^)]+)\)\s+q\[(\d+)\];"

            # Busca coincidències
           m = match(pattern, line)

          if m === nothing
               error("Format de línia incorrecte. S'esperava 'p(angle) q[qubit];'")
          end

           # Extreu i converteix els valors
           angle_str = m.captures[1]
           qubit_str = m.captures[2]

          # Analitza l'angle (pot contenir expressions matemàtiques com pi/2)
           angle = eval(Meta.parse(angle_str))

           # Converteix el qubit a enter
           qubit = parse(Int, qubit_str) + 1



            #Ara creem la porta particular
            phi=angle;
            #lambda=angle2
            matriu = p(phi)
            nova_porta_1q_p=create_gate_1q("nova_porta_1q_p", p(phi))
            circ << u(nova_porta_1q_p, qubit)

        elseif occursin(r"^sx\s+q\[", line)
             # Processa sx (equivalent a rx(pi/2))
                m = match(r"sx\s+q\[(\d+)\];", line)
                angle = pi/2
                qubit = parse(Int, m.captures[1]) + 1
                #println("$angle, angle i qubit $qubit en la porta sx")
                Circuit.add_gatecall!(circ, r_x(qubit, angle))

        elseif occursin(r"^ry\(", line)
            m = match(r"ry\((.*)\)\s+q\[(\d+)\];", line)
            angle = eval(Meta.parse(m.captures[1]))
            qubit = parse(Int, m.captures[2]) + 1
            Circuit.add_gatecall!(circ, r_y(qubit, angle))

        elseif occursin(r"^rz\(", line)
            m = match(r"rz\((.*)\)\s+q\[(\d+)\];", line)
            angle = eval(Meta.parse(m.captures[1]))
            qubit = parse(Int, m.captures[2]) + 1
            Circuit.add_gatecall!(circ, r_z(qubit, angle))

        # Portes de dos qubits no paramètriques
        elseif occursin(r"^cx\s+q\[", line)
            m = match(r"cx\s+q\[(\d+)\],\s*q\[(\d+)\];", line)
            ctrl = parse(Int, m.captures[1]) + 1
            target = parse(Int, m.captures[2]) + 1
            Circuit.add_gatecall!(circ, c_x(target,ctrl))

        elseif occursin(r"^cy\s+q\[", line)
            m = match(r"cy\s+q\[(\d+)\],\s*q\[(\d+)\];", line)
            ctrl = parse(Int, m.captures[1]) + 1
            target = parse(Int, m.captures[2]) + 1
            Circuit.add_gatecall!(circ, c_y(target, ctrl))

        elseif occursin(r"^cz\s+q\[", line)
            m = match(r"cz\s+q\[(\d+)\],\s*q\[(\d+)\];", line)
            ctrl = parse(Int, m.captures[1]) + 1
            target = parse(Int, m.captures[2]) + 1
            Circuit.add_gatecall!(circ, c_z(target,ctrl))

        # Porta swap
        elseif occursin(r"^swap\s+q\[", line)
            m = match(r"swap\s+q\[(\d+)\],\s*q\[(\d+)\];", line)
            qubit1 = parse(Int, m.captures[1]) + 1
            qubit2 = parse(Int, m.captures[2]) + 1
            Circuit.add_gatecall!(circ, swap(qubit1, qubit2))

        # Porta CP (Phase Controlada) paramètrica
        elseif occursin(r"^cp\(", line)
            m = match(r"cp\((.*)\)\s+q\[(\d+)\],\s*q\[(\d+)\];", line)
            if m !== nothing
                angle = eval(Meta.parse(m.captures[1]))
                ctrl = parse(Int, m.captures[2]) + 1
                target = parse(Int, m.captures[3]) + 1
                #add_gatecall!(circ, c_phase(ctrl, target, angle))
                circ << c_r_phase(target,ctrl, angle)
            else
                @warn "Format incorrecte per a porta CP: $line"
            end



        else
             println(" Element no processat: $line ")
        end
    catch e
        @warn "No s'ha pogut processar la línia: $line. Error: $e"
    end
end

#Creem  funcions genèriques en QXZoo per a arreplegar u1 i u2 , p i altres de Qiskit

using QXZoo
using LinearAlgebra

# Definim U₂(0,0) ≈ Hadamard (H)
function u2(phi, lambda)
    return (1/sqrt(2)) * [
        1                    -exp(im * lambda);
        exp(im * phi)         exp(im * (phi + lambda))
    ]
end



# Definim U1
function u1(phi)
    return  [
        1            0   ;
        0          exp(im * (phi))
    ]
end

# Definim p que és la mateixa que u1
function p(phi)
    return  [
        1            0   ;
        0          exp(im * (phi))
    ]
end


# Two qubit gates


function phase_gate_2qubits(phi)
    # Matriu 4x4 per a 2 qubits
    [1 0 0 0;
     0 1 0 0;
     0 0 1 0;
     0 0 0 exp(im*phi)]
end


## Adaptació dels fiters QWalk per a poder usar-los en QXZoo canviant els noms dels qubits

function replace_qasm_registers_grover(input_file::String, output_file::String="output.qasm")
    # Llegir el contingut del fitxer
    content = read(input_file, String)

    # Crear diccionari de substitució
    replacements = Dict{String,String}()

    # Processar les definicions de registres
    node_q=0
    node_count = 0
    coin_count = 0
    flag_count = 0

   # Trobar definicions de registres
    for line in split(content, '\n')
     #println(line)
        if occursin(r"qreg\s+node\[(\d+)\];", line)
            node_count = parse(Int, match(r"qreg\s+node\[(\d+)\];", line).captures[1])
            println("node_count: $node_count")
        elseif occursin(r"qreg\sq\[(\d+)\];", line)
            node_q = parse(Int, match(r"qreg\sq\[(\d+)\];", line).captures[1])
           println("node_q: $node_q")
        elseif occursin(r"qreg\s+coin\[(\d+)\];", line)
            coin_count = parse(Int, match(r"qreg\s+coin\[(\d+)\];", line).captures[1])
             println(coin_count)
             println("coin count:$coin_count")
        elseif occursin(r"qreg\s+flag\[(\d+)\];", line)
            flag_count = parse(Int, match(r"qreg\s+flag\[(\d+)\];", line).captures[1])
             println("flag count:$flag_count")
        end
    end

    # Generar substitució per node
    for i in 0:(node_count-1)
        replacements["node[$i]"] = "q[$i]"
    end

    # Generar substitució per coin
    for i in 0:(coin_count-1)
        replacements["coin[$i]"] = "q[$(i+node_count)]"
    end
     # Generar substitució per flag
    for i in 0:(flag_count-1)
        replacements["flag[$i]"] = "q[$(i+node_q)]"
    end

    # Reemplaçar al contingut
    new_content = content
    for (old, new) in replacements
        new_content = replace(new_content, old => new)
    end

    # Reemplaçar la definici| ó dels registres
    if node_q > 0 || node_count > 0 || coin_count > 0 || flag_count > 0
        total_qubits = node_count + coin_count + flag_count + node_q
        #println(total_qubits)
        # new_content = replace(new_content, r"qreg\s+node\[\d+\];\s*qreg\s+coin\[\d+\];" => "qreg q[$total_qubits];")
        new_content = replace(new_content, r"qreg\s+q\[\d+\];\s*qreg\s+flag\[\d+\];" => "qreg q[$total_qubits];")
        #println(new_content)
    end

    # Escriure el fitxer de sortida
    write(output_file, new_content)

    return new_content
end



# aquesta funció corregix l'error que hi havia en  la penúltima versió de la funció
# En qiskit és control, target i en QXZoo a l'inrevés

function process_gate_line!(circ::QXZoo.Circuit.Circ, line::String)
    try
        # Eliminar espais inicials i finals
        line = strip(line)

        # Portes d'un sol qubit no paramètriques
        if occursin(r"^x\s+q\[", line)
            qubit = parse(Int, match(r"x\s+q\[(\d+)\];", line).captures[1]) + 1
            Circuit.add_gatecall!(circ, x(qubit))

        elseif occursin(r"^y\s+q\[", line)
            qubit = parse(Int, match(r"y\s+q\[(\d+)\];", line).captures[1]) + 1
            Circuit.add_gatecall!(circ, y(qubit))

        elseif occursin(r"^z\s+q\[", line)
            qubit = parse(Int, match(r"z\s+q\[(\d+)\];", line).captures[1]) + 1
            Circuit.add_gatecall!(circ, z(qubit))

        elseif occursin(r"^h\s+q\[", line)
            qubit = parse(Int, match(r"h\s+q\[(\d+)\];", line).captures[1]) + 1
            Circuit.add_gatecall!(circ, h(qubit))

        elseif occursin(r"^s\s+q\[", line)
            qubit = parse(Int, match(r"s\s+q\[(\d+)\];", line).captures[1]) + 1
            Circuit.add_gatecall!(circ, s(qubit))

        elseif occursin(r"^t\s+q\[", line)
            qubit = parse(Int, match(r"t\s+q\[(\d+)\];", line).captures[1]) + 1
            Circuit.add_gatecall!(circ, t(qubit))

        # Portes paramètriques d'un sol qubit (sense espai després del nom)
        elseif occursin(r"^rx\(", line)
            m = match(r"rx\((.*)\)\s+q\[(\d+)\];", line)
            angle = eval(Meta.parse(m.captures[1]))  # Permet expressions com pi/2
            qubit = parse(Int, m.captures[2]) + 1
            Circuit.add_gatecall!(circ, r_x(qubit, angle))

         # afegim nous patrons de cerca per a u2 i u1
        elseif  occursin(r"^u2\(", line)
            pattern = r"u2\(([^,]+),\s*([^)]+)\)\s+q\[(\d+)\]"
            # Busca coincidències
            m = match(pattern, line)

           if m === nothing
                error("Format de línia incorrecte. S'esperava 'u2(angle1,angle2) q[qubit]'")
            end

            # Extreu i converteix els valors
            angle1_str = m.captures[1]
            angle2_str = m.captures[2]
            qubit_str = m.captures[3]

            # Analitza els angles (pot contenir expressions matemàtiques com pi/2)
           angle1 = eval(Meta.parse(angle1_str))
           angle2 = eval(Meta.parse(angle2_str))

           # Converteix el qubit a enter
            qubit = parse(Int, qubit_str) + 1
            #Ara creem la porta particular
            phi=angle1;
            lambda=angle2
            matriu = u2(phi, lambda)
            nova_porta_1q_u2=create_gate_1q("nova_porta_1q_u2", u2(phi, lambda))
            circ << u(nova_porta_1q_u2, qubit)

          # afegim nous patrons de cerca per a u2 i u1
        elseif  occursin(r"^u1\(", line)

            pattern = r"u1\(([^)]+)\)\s+q\[(\d+)\];"

            # Busca coincidències
           m = match(pattern, line)

          if m === nothing
               error("Format de línia incorrecte. S'esperava 'u1(angle) q[qubit];'")
          end

           # Extreu i converteix els valors
           angle_str = m.captures[1]
           qubit_str = m.captures[2]

          # Analitza l'angle (pot contenir expressions matemàtiques com pi/2)
           angle = eval(Meta.parse(angle_str))

           # Converteix el qubit a enter
           qubit = parse(Int, qubit_str) + 1



            #Ara creem la porta particular
            phi=angle;
            #lambda=angle2
            matriu = u1(phi)
            nova_porta_1q_u1=create_gate_1q("nova_porta_1q_u1", u1(phi))
            circ << u(nova_porta_1q_u1, qubit)

            # afegim nous patrons de cerca per a la porta p
        elseif  occursin(r"^p\(", line)

            pattern = r"p\(([^)]+)\)\s+q\[(\d+)\];"

            # Busca coincidències
           m = match(pattern, line)

          if m === nothing
               error("Format de línia incorrecte. S'esperava 'p(angle) q[qubit];'")
          end

           # Extreu i converteix els valors
           angle_str = m.captures[1]
           qubit_str = m.captures[2]

          # Analitza l'angle (pot contenir expressions matemàtiques com pi/2)
           angle = eval(Meta.parse(angle_str))

           # Converteix el qubit a enter
           qubit = parse(Int, qubit_str) + 1



            #Ara creem la porta particular
            phi=angle;
            #lambda=angle2
            matriu = p(phi)
            nova_porta_1q_p=create_gate_1q("nova_porta_1q_p", p(phi))
            circ << u(nova_porta_1q_p, qubit)

        elseif occursin(r"^sx\s+q\[", line)
             # Processa sx (equivalent a rx(pi/2))
                m = match(r"sx\s+q\[(\d+)\];", line)
                angle = pi/2
                qubit = parse(Int, m.captures[1]) + 1
                #println("$angle, angle i qubit $qubit en la porta sx")
                Circuit.add_gatecall!(circ, r_x(qubit, angle))

        elseif occursin(r"^ry\(", line)
            m = match(r"ry\((.*)\)\s+q\[(\d+)\];", line)
            angle = eval(Meta.parse(m.captures[1]))
            qubit = parse(Int, m.captures[2]) + 1
            Circuit.add_gatecall!(circ, r_y(qubit, angle))

        elseif occursin(r"^rz\(", line)
            m = match(r"rz\((.*)\)\s+q\[(\d+)\];", line)
            angle = eval(Meta.parse(m.captures[1]))
            qubit = parse(Int, m.captures[2]) + 1
            Circuit.add_gatecall!(circ, r_z(qubit, angle))

        # Portes de dos qubits no paramètriques
        elseif occursin(r"^cx\s+q\[", line)
            m = match(r"cx\s+q\[(\d+)\],\s*q\[(\d+)\];", line)
            ctrl = parse(Int, m.captures[1]) + 1
            target = parse(Int, m.captures[2]) + 1
            Circuit.add_gatecall!(circ, c_x(target,ctrl))

        elseif occursin(r"^cy\s+q\[", line)
            m = match(r"cy\s+q\[(\d+)\],\s*q\[(\d+)\];", line)
            ctrl = parse(Int, m.captures[1]) + 1
            target = parse(Int, m.captures[2]) + 1
            Circuit.add_gatecall!(circ, c_y(target, ctrl))

        elseif occursin(r"^cz\s+q\[", line)
            m = match(r"cz\s+q\[(\d+)\],\s*q\[(\d+)\];", line)
            ctrl = parse(Int, m.captures[1]) + 1
            target = parse(Int, m.captures[2]) + 1
            Circuit.add_gatecall!(circ, c_z(target,ctrl))

            # afegim nova porta de dos qubits cu1

        elseif  occursin(r"^cu1\(", line)

            # Patró regex per extreure els components
                pattern = r"cu1\(([^)]+)\)\s+q\[(\d+)\],q\[(\d+)\];"

              # Busca coincidències
              m = match(pattern, line)

             if m === nothing
                error("Format de línia incorrecte. S'esperava 'cu1(angle) q[qubit1],q[qubit2];'")
             end

            # Extreu i converteix els valors
             angle_str = m.captures[1]
             qubit1_str = m.captures[2]
             qubit2_str = m.captures[3]

           # Analitza l'angle (pot contenir expressions com pi/2)
           angle = eval(Meta.parse(angle_str))

            # Converteix els qubits a enters
            qubit1 = parse(Int, qubit1_str) + 1
            qubit2 = parse(Int, qubit2_str) + 1

            phi=angle;
            #lambda=angle2

            nova_porta_2q_cu1 = create_gate_2q("nova_porta_2q_cu1", phase_gate_2qubits(phi))
            #circ << u(nova_porta_1q_u2, qubit)
            circ << c_u( nova_porta_2q_cu1, qubit1,qubit2)


        # Porta swap
        elseif occursin(r"^swap\s+q\[", line)
            m = match(r"swap\s+q\[(\d+)\],\s*q\[(\d+)\];", line)
            qubit1 = parse(Int, m.captures[1]) + 1
            qubit2 = parse(Int, m.captures[2]) + 1
            Circuit.add_gatecall!(circ, swap(qubit1, qubit2))

        # Porta CP (Phase Controlada) paramètrica
        elseif occursin(r"^cp\(", line)
            m = match(r"cp\((.*)\)\s+q\[(\d+)\],\s*q\[(\d+)\];", line)
            if m !== nothing
                angle = eval(Meta.parse(m.captures[1]))
                ctrl = parse(Int, m.captures[2]) + 1
                target = parse(Int, m.captures[3]) + 1
                #add_gatecall!(circ, c_phase(ctrl, target, angle))
                circ << c_r_phase(target,ctrl, angle)
            else
                @warn "Format incorrecte per a porta CP: $line"
            end



        else
             println(" Element no processat: $line ")
        end
    catch e
        @warn "No s'ha pogut processar la línia: $line. Error: $e"
    end
end


## Adaptació dels fiters Qpee per a poder usar-los en QXZoo canviant els noms dels qubits

function replace_qasm_registers_qpe_exact(input_file::String, output_file::String="output.qasm")
    # Llegir el contingut del fitxer
    content = read(input_file, String)

    # Crear diccionari de substitució
    replacements = Dict{String,String}()

    # Processar les definicions de registres
    node_q=0
    node_count = 0
    coin_count = 0
    psi_count = 0

   # Trobar definicions de registres
    for line in split(content, '\n')
     #println(line)
        if occursin(r"qreg\s+node\[(\d+)\];", line)
            node_count = parse(Int, match(r"qreg\s+node\[(\d+)\];", line).captures[1])
            println("node_count: $node_count")
        elseif occursin(r"qreg\sq\[(\d+)\];", line)
            node_q = parse(Int, match(r"qreg\sq\[(\d+)\];", line).captures[1])
           println("node_q: $node_q")
        elseif occursin(r"qreg\s+coin\[(\d+)\];", line)
            coin_count = parse(Int, match(r"qreg\s+coin\[(\d+)\];", line).captures[1])
             println(coin_count)
             println("coin count:$coin_count")
        elseif occursin(r"qreg\s+psi\[(\d+)\];", line)
            psi_count = parse(Int, match(r"qreg\s+psi\[(\d+)\];", line).captures[1])
             println("psi count:$psi_count")
        end
    end

    # Generar substitució per node
    for i in 0:(node_count-1)
        replacements["node[$i]"] = "q[$i]"
    end

    # Generar substitució per coin
    for i in 0:(coin_count-1)
        replacements["coin[$i]"] = "q[$(i+node_count)]"
    end
     # Generar substitució per flag
    for i in 0:(psi_count-1)
        replacements["psi[$i]"] = "q[$(i+node_q)]"
    end

    # Reemplaçar al contingut
    new_content = content
    for (old, new) in replacements
        new_content = replace(new_content, old => new)
    end

    # Reemplaçar la definici| ó dels registres
    if node_q > 0 || node_count > 0 || coin_count > 0 || psi_count > 0
        total_qubits = node_count + coin_count + psi_count + node_q
        #println(total_qubits)
        # new_content = replace(new_content, r"qreg\s+node\[\d+\];\s*qreg\s+coin\[\d+\];" => "qreg q[$total_qubits];")
        new_content = replace(new_content, r"qreg\s+q\[\d+\];\s*qreg\s+psi\[\d+\];" => "qreg q[$total_qubits];")
        #println(new_content)
    end

    # Escriure el fitxer de sortida
    write(output_file, new_content)

    return new_content
end

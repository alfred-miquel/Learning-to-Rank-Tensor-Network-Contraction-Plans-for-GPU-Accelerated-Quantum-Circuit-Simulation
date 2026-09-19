using DataFrames, Statistics #, Plots

# Estructura per a emmagatzemar les dades de cada contracció
struct Contraction
    tensorA::String
    tensorB::String
    tensorC::String
    rankA::Int
    rankB::Int
    rankC::Int
    common_indices::String
    num_common_indices::Int
    time::Float64
end


#modifiquem la funció de dalt per a poder computar la longitut dels indexs a posteriori

using DataFrames, Statistics #,Plots

const index_max = 100 # suposem que el rang maxim que podrem compartir ser+a 100. Es un poc massa però..



# Funció per a llegir de l'arxiu i parsejar les dades
function read_contractions_analisi_ranks_indexs(filename::String; verbose=true)

     #iniciem els comptadors
    comptador= [0 for i in 1:index_max]
    ranks_A  =  [0 for i in 1:index_max]
    ranks_B  =  [0 for i in 1:index_max]
    ranks_C  =  [0 for i in 1:index_max]
    #iniciem el vector de suma de rangs
    ranks_AB =[0 for i in 1:2*index_max]
    ranks_AB_d  =  [0 for i in 1:index_max]
    zeros=[] #element de depuració vegades on la resta de rangs dona zero
    contractions = Contraction[]
    open(filename, "r") do file
        for line in eachline(file)
            # Dividir la línea en componentes
            parts = split(line)

            # Extraer los campos básicos
            tensorA = parts[1]
            tensorB = parts[2]
            tensorC = parts[3]
            rankA = parse(Int, parts[4])
            rankB = parse(Int, parts[5])
            rankC = parse(Int, parts[6])

             rankAB=rankA + rankB # sumem els dos rangs per a veure
             #push!(ranks_AB,rankAB)
             rankAB_d= abs(rankA - rankB) # mirem les diferències
             if verbose == true
              println("-----------------------------")
              println("rankAB_d: $rankAB_d ")
              println("rankC: $rankC")
              println("rankA: $rankA")
              println("rankB: $rankB")
            end
            # Els índexs comuns poden contenir espais, així que els enjuntem
            common_indices = join(parts[7:end-1], " ") #modifiquem end-2
            # num_common_indices = parse(Int, parts[end-1]) #llevem el penúltim camp i el calculem
            divisio = ((rankA + rankB) -rankC)/2
            num_common_indices= Int(divisio)
            #println(num_common_indices)
            time = parse(Float64, parts[end])
            a= Contraction(tensorA, tensorB, tensorC,
                                          rankA, rankB, rankC,
                                          common_indices, num_common_indices, time)
            if num_common_indices > 1  && verbose
                println(a)
            end
            #recull de dades
             # comptador[num_common_indices] = comptador[num_common_indices] +1
             ranks_A[rankA] = ranks_A[rankA] +1
             ranks_B[rankB] = ranks_B[rankB] +1
             ranks_AB[rankA+rankB] = ranks_AB[rankA+rankB] +1

            if rankAB_d != 0
               ranks_AB_d[rankAB_d] = ranks_AB_d[rankAB_d] +1
            else
               if verbose==true
                  println("La resta en valor absolut de rangs A i B ha donat zero")
                  println("-----------------------------")
                  println()
                end

                push!(zeros,(rankA,rankB))


              end

             if rankC != 0
                ranks_C[rankC] = ranks_C[rankC] +1
                comptador[num_common_indices] = comptador[num_common_indices] +1

            else
                if verbose==true
                  println("La contracció de dos tensors de rang A $rankA i  rang B $rankB ha donat un tensors C amb rang $rankC ")
                  println("Normalment serà la contracció final")
                  println()
                end
            end
            # Crea i emmagatzema la contracció i el vector de suma de rangs
            push!(contractions, a)



            #println(contractions)
        end
    end
    return contractions,comptador,ranks_A,ranks_B,ranks_C,ranks_AB,ranks_AB_d,zeros
end


using Statistics

function calcular_estadistics_optim(valors, freqüències)
    # Verificar que les longituds coincideixen
    if length(valors) != length(freqüències)
        error("Els vectors de valors i freqüències han de tenir la mateixa longitud")
    end

    # Calcular estadístics sense expandir el vector
    n = sum(freqüències)
    suma = sum(valors .* freqüències)
    mitjana = suma / n

    # Calcular variància sense expandir
    suma_quadrats = sum((valors .- mitjana).^2 .* freqüències)
    variancia = suma_quadrats / (n - 1)  # Variància mostral
    desviacio = sqrt(variancia)

    # Crear diccionari per als resultats
    estadistics = Dict{String, Float64}()

    # Estadístics bàsics
    estadistics["Nombre d'observacions"] = n
    estadistics["Mínim"] = minimum(valors)
    estadistics["Màxim"] = maximum(valors)
    estadistics["Mitjana"] = mitjana

    # Calcular mediana sense expandir
    freq_acumulades = cumsum(freqüències)
    mediana_pos = n / 2
    idx_mediana = findfirst(>=(mediana_pos), freq_acumulades)

    if n % 2 == 0 && freq_acumulades[idx_mediana] == mediana_pos
        # Cas parell: promig dels dos valors centrals
        mediana = (valors[idx_mediana] + valors[idx_mediana+1]) / 2
    else
        mediana = valors[idx_mediana]
    end
    estadistics["Mediana"] = mediana

    # Moda (valor amb freqüència més alta)
    estadistics["Moda"] = valors[argmax(freqüències)]

    # Mesures de dispersió
    estadistics["Variància"] = variancia
    estadistics["Desviació estàndard"] = desviacio
    estadistics["Coeficient de variació"] = (desviacio / mitjana) * 100  # En percentatge

    # Funció per calcular qualsevol quantil
    function calcular_quantil(q)
        pos = q * n
        if pos < 1
            return valors[1]
        elseif pos > n
            return valors[end]
        end

        idx = findfirst(>=(pos), freq_acumulades)
        if idx == 1
            return valors[1]
        end

        if freq_acumulades[idx-1] == floor(pos)
            return valors[idx-1]
        else
            # Interpolació lineal
            lower_val = valors[idx-1]
            upper_val = valors[idx]
            lower_cum = idx > 1 ? freq_acumulades[idx-1] : 0
            upper_cum = freq_acumulades[idx]
            weight = (pos - lower_cum) / (upper_cum - lower_cum)
            return lower_val + weight * (upper_val - lower_val)
        end
    end

    # Quartils
    estadistics["Primer quartil (Q1)"] = calcular_quantil(0.25)
    estadistics["Segon quartil (Q2/Mediana)"] = mediana  # Ja calculada
    estadistics["Tercer quartil (Q3)"] = calcular_quantil(0.75)
    estadistics["Rang interquartílic (IQR)"] = estadistics["Tercer quartil (Q3)"] - estadistics["Primer quartil (Q1)"]

    # Asimetria i curtosi (sense expandir)
    if desviacio > 0
        moment_3 = sum((valors .- mitjana).^3 .* freqüències) / n
        moment_4 = sum((valors .- mitjana).^4 .* freqüències) / n
        estadistics["Asimetria"] = moment_3 / (desviacio^3)
        estadistics["Curtosi"] = (moment_4 / (desviacio^4)) - 3  # Excess kurtosis
    else
        estadistics["Asimetria"] = 0.0
        estadistics["Curtosi"] = 0.0
    end

    return estadistics
end

#aquesta funció és pera evitar copiar-ho cada vegada, la prèvia

function preparacio_estadistics(comptador,ranks_A,ranks_B,ranks_C)
    # ho posem tot junt

indexs=[]
frequencies_indexs=[]
for i in 1:length(comptador)
    if comptador[i] != 0
        println("nombre de índexs: $i, vegades que es contrauen : $(comptador[i])")
        push!(indexs,i)
        push!(frequencies_indexs,comptador[i])
    end
end

println("+++++++++++++++++++++++++++++++++++++++++++++++++++")
rangs_A=[]
frequencies_A=[]
for i in 1:length(ranks_A)
    if ranks_A[i] != 0
        println("Els rangs dels tensor  A: $i, han eixit : $(ranks_A[i]) vegades ")
        push!(rangs_A,i)
        push!(frequencies_A,ranks_A[i])
    end
end

println("+++++++++++++++++++++++++++++++++++++++++++++++++++")

rangs_B=[]
frequencies_B=[]
for i in 1:length(ranks_B)
    if ranks_B[i] != 0
        println("Els rangs dels tensor  B: $i, han eixit : $(ranks_B[i]) vegades ")
        push!(rangs_B,i)
        push!(frequencies_B,ranks_B[i])
    end
end

println("+++++++++++++++++++++++++++++++++++++++++++++++++++")

rangs_C=[]
frequencies_C=[]
for i in 1:length(ranks_C)
    if ranks_C[i] != 0
        println("Els rangs dels tensor  C: $i, han eixit : $(ranks_C[i]) vegades ")
        push!(rangs_C,i)
        push!(frequencies_C,ranks_C[i])
    end
end

return indexs,frequencies_indexs,rangs_A,frequencies_A,rangs_B,frequencies_B,rangs_C,frequencies_C
end


function preparacio_estadistics_ampliat_continuacio(ranks_AB,ranks_AB_d)
    # ho posem tot junt

rangs_AB=[]
frequencies_AB=[]
for i in 1:length(ranks_AB)
    if ranks_AB[i] != 0
        println("Els rangs dels tensors suma A i B: $i, han eixit : $(ranks_AB[i]) vegades ")
        push!(rangs_AB,i)
        push!(frequencies_AB,ranks_AB[i])
    end
end
     println("+++++++++++++++++++++++++++++++++++++++++++++++++++")

r_AB_d = []
frequencies_AB_d = []
for i in 1:length(ranks_AB_d)
    if ranks_AB_d[i] != 0
        println("Els rangs dels tensors difèrencia en valor absolut A i B: $i, han eixit : $(ranks_AB_d[i]) vegades ")
        push!(r_AB_d,i)
        push!(frequencies_AB_d,ranks_AB_d[i])
    end
end
   println("+++++++++++++++++++++++++++++++++++++++++++++++++++")


return  rangs_AB,frequencies_AB, r_AB_d ,frequencies_AB_d

end



# Aquesta funció és una fusió de les dues anteriors
function preparacio_estadistics_global(comptador,ranks_A,ranks_B,ranks_C,ranks_AB,ranks_AB_d)

   indexs=[]
frequencies_indexs=[]
for i in 1:length(comptador)
    if comptador[i] != 0
        println("nombre de índexs: $i, vegades que es contrauen : $(comptador[i])")
        push!(indexs,i)
        push!(frequencies_indexs,comptador[i])
    end
end

println("+++++++++++++++++++++++++++++++++++++++++++++++++++")
rangs_A=[]
frequencies_A=[]
for i in 1:length(ranks_A)
    if ranks_A[i] != 0
        println("Els rangs dels tensor  A: $i, han eixit : $(ranks_A[i]) vegades ")
        push!(rangs_A,i)
        push!(frequencies_A,ranks_A[i])
    end
end

println("+++++++++++++++++++++++++++++++++++++++++++++++++++")

rangs_B=[]
frequencies_B=[]
for i in 1:length(ranks_B)
    if ranks_B[i] != 0
        println("Els rangs dels tensor  B: $i, han eixit : $(ranks_B[i]) vegades ")
        push!(rangs_B,i)
        push!(frequencies_B,ranks_B[i])
    end
end

println("+++++++++++++++++++++++++++++++++++++++++++++++++++")

rangs_C=[]
frequencies_C=[]
for i in 1:length(ranks_C)
    if ranks_C[i] != 0
        println("Els rangs dels tensor  C: $i, han eixit : $(ranks_C[i]) vegades ")
        push!(rangs_C,i)
        push!(frequencies_C,ranks_C[i])
    end
end
     println("+++++++++++++++++++++++++++++++++++++++++++++++++++")

    rangs_AB=[]
frequencies_AB=[]
for i in 1:length(ranks_AB)
    if ranks_AB[i] != 0
        println("Els rangs dels tensors suma A i B: $i, han eixit : $(ranks_AB[i]) vegades ")
        push!(rangs_AB,i)
        push!(frequencies_AB,ranks_AB[i])
    end
end
     println("+++++++++++++++++++++++++++++++++++++++++++++++++++")

r_AB_d = []
frequencies_AB_d = []
for i in 1:length(ranks_AB_d)
    if ranks_AB_d[i] != 0
        println("Els rangs dels tensors difèrencia en valor absolut A i B: $i, han eixit : $(ranks_AB_d[i]) vegades ")
        push!(r_AB_d,i)
        push!(frequencies_AB_d,ranks_AB_d[i])
    end
end
   println("+++++++++++++++++++++++++++++++++++++++++++++++++++")


return indexs,frequencies_indexs,rangs_A,frequencies_A,rangs_B,frequencies_B,rangs_C,frequencies_C ,rangs_AB,frequencies_AB, r_AB_d ,frequencies_AB_d

end


    # Aquesta funció em dona les frequencies en què hi ha contracció de tensors del mateix rang
# El vector de Zeros ens dona parelles de rangs de tensors contraguts (2,2), (3,3)  etc ..
function analisi_zero(Zeros)
    frequencies= [0 for i in 1:maximum(Zeros)[1]]
    for j in 1:maximum(Zeros)[1]
      for i in (Zeros)

        if j == i[1]
           # println("Entra j=$j")
            # println("i val : $i")
            # println("j val $j")

            frequencies[j]=  frequencies[j]+1
        end
    end
end
    return frequencies
end


# ordena de major a menor un vector i retorna un vector d'index amb la posició original
function ordena_amb_posicions(vector)
    index_ordenats = sortperm(vector, rev=true)
    return vector[index_ordenats], index_ordenats
end

function expandir_dades(dades, freqüències)
    expandida = []
    for (d, f) in zip(dades, freqüències)
        append!(expandida, fill(d, f))
    end
    return expandida
end

function calcular_moda(dades, freqüències)
    dades_expandides = expandir_dades(dades, freqüències)
    counts = Dict{eltype(dades_expandides), Int}()
    for d in dades_expandides
        counts[d] = get(counts, d, 0) + 1
    end
    max_freq = maximum(values(counts))
    moda = [k for (k,v) in counts if v == max_freq]
    return length(moda) == 1 ? moda[1] : moda
end

function calcular_quartils(dades, freqüències)
    dades_expandides = expandir_dades(dades, freqüències)
    sort!(dades_expandides)
    return (Q1=quantile(dades_expandides, 0.25),
            Q2=quantile(dades_expandides, 0.50),
            Q3=quantile(dades_expandides, 0.75))
end

function calcular_percentil(dades, freqüències, p)
    (0 <= p <= 100) || error("El percentil ha d'estar entre 0 i 100")
    dades_expandides = expandir_dades(dades, freqüències)
    sort!(dades_expandides)
    return quantile(dades_expandides, p/100)
end

function calcular_asimetria(dades, freqüències)
    dades_expandides = expandir_dades(dades, freqüències)
    m = mean(dades_expandides)
    s = std(dades_expandides)
    n = length(dades_expandides)
    return (sum((x - m)^3 for x in dades_expandides) / n) / s^3
end

function calcular_curtosi(dades, freqüències)
    dades_expandides = expandir_dades(dades, freqüències)
    m = mean(dades_expandides)
    s = std(dades_expandides)
    n = length(dades_expandides)
    return ((sum((x - m)^4 for x in dades_expandides) / n) / s^4) - 3
end

function calcular_entropia(dades, freqüències)
    dades_expandides = expandir_dades(dades, freqüències)
    total = length(dades_expandides)
    probabilitats = [count(==(x), dades_expandides)/total for x in unique(dades_expandides)]
    return -sum(p * log(p) for p in probabilitats if p > 0)
end

function Estadistics(dades::Vector{<:Real}, freqüències::Vector{<:Integer})::Dict{String, Any}
    # Verificació de les dades
    length(dades) == length(freqüències) || error("Les dades i freqüències han de tenir la mateixa longitud")
    all(f -> f ≥ 0, freqüències) || error("Les freqüències no poden ser negatives")
    sum(freqüències) > 0 || error("La suma de freqüències ha de ser major que zero")

    # Expandim les dades
    dades_expandides = expandir_dades(dades, freqüències)
    n = length(dades_expandides)

    # Càlculs bàsics
    mitjana = mean(dades_expandides)
    desviacio = std(dades_expandides, corrected=true)
    quartils = calcular_quartils(dades, freqüències)

    # Diccionari de resultats
    resultats = Dict{String, Any}(
        "Nombre d'observacions" => n,
        "Mitjana" => mitjana,
        "Mediana" => quartils.Q2,
        "Moda" => calcular_moda(dades, freqüències),
        "Desviació estàndard" => desviacio,
        "Variància" => var(dades_expandides, corrected=true),
        "Mínim" => minimum(dades_expandides),
        "Màxim" => maximum(dades_expandides),
        "Rang" => maximum(dades_expandides) - minimum(dades_expandides),
        "Quartil Q1" => quartils.Q1,
        "Quartil Q3" => quartils.Q3,
        "Interval interquartílic" => quartils.Q3 - quartils.Q1,
        "Coeficient de variació" => (desviacio / mitjana) * 100,
        "Asimetria" => calcular_asimetria(dades, freqüències),
        "Curtosi" => calcular_curtosi(dades, freqüències),
        "Entropia" => calcular_entropia(dades, freqüències),
        "Suma" => sum(dades_expandides)
    )

    # Percentils
    for p in [5, 10, 25,30,35,40,45,50, 55, 60, 75,80, 90, 95,99] # AsTò ho podem modular per obtenir més o menys p
        resultats["Percentil $p"] = calcular_percentil(dades, freqüències, p)
    end

    return resultats
end

function mostrar_estadistics(resultats::Dict{String, Any})
    println("\nESTADÍSTICS DESCRIPTIUS\n")
    for (k, v) in sort(collect(resultats), by=x->x[1])
        if isa(v, AbstractFloat)
            println(rpad(k, 25), " = ", round(v, digits=4))
        else
            println(rpad(k, 25), " = ", v)
        end
    end
end

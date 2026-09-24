## notebook: model predictions. Required functions

using Statistics
using XGBoost
using XLSX
using DataFrames


# features from the article

feature_names = [
        "max_cost",              # 1. max cost
        "log2_sum_flops_val",    # 2. log2 sum flops
        "topq_mean",             # 3. topq mean cost
        "avg_cost",              # 4. avg cost
        "std_cost",              # 5. std cost
        "n_steps",               # 6. n steps
        "frac_tiny",             # 7. frac tiny steps
        "max_out_rank",          # 8. max out rank
        "avg_out_rank",          # 9. avg out rank
        "costw_out_rank",        # 10. costw out rank
        "p_at_max_cost_val",     # 11. p at max cost
        "max_red_rank_val",      # 12. max red rank
        "costw_red_rank_val",    # 13. costw red rank
        "k_at_max_cost_val",     # 14. k at max cost
        "max_asym_val",          # 15. max asym 
        "avg_asym",              # 16. avg asym
        "costw_asym_val",        # 17. costw asym 
        "d_at_max_cost_val"      # 18. d at max cost
    ]



features_13 = [

            
 "std_cost"
 "n_steps"
 "frac_tiny"
 "max_out_rank"
 "avg_out_rank"
 "costw_out_rank"
 "p_at_max_cost_val"
 "max_red_rank_val"
 "k_at_max_cost_val"
 "max_asym_val"
 "avg_asym"
 "costw_asym_val"
 "d_at_max_cost_val"
   
    ]




function llegir_dataframe_excel_corregit(ruta_arxiu::String; nom_full::String="",versio=false)
    """
    Llegeix un DataFrame des d'un arxiu Excel (versió corregida).
    """
    
    try
        # Mostrar informació dels fulls disponibles
        xf = XLSX.readxlsx(ruta_arxiu)
        fulls = XLSX.sheetnames(xf)
        println("📑 Fulls disponibles: $fulls")
        
        # Determinar quin full llegir
        full_a_llegir = isempty(nom_full) ? fulls[1] : nom_full
        println("📖 Llegint full: '$full_a_llegir'")
        
        # Llegir les dades com a DataTable
        datatable = XLSX.readtable(ruta_arxiu, full_a_llegir)
        
        # Convertir DataTable a DataFrame
        df = DataFrame(datatable)

        if versio == true
          # Tancar el fitxer
          XLSX.close(xf)
        end
        
        println("✅ DataFrame llegit correctament")
        println("📊 Dimensions: $(nrow(df)) files × $(ncol(df)) columnes")
        println("📋 Columnes: $(names(df))")
        
        return df
        
    catch e
        println("❌ Error en llegir l'arxiu Excel: $e")
        rethrow(e)
    end
end


function selecciona_columnes(df, columnes)
    disponibles = Set(names(df))
    faltants = [c for c in columnes if !(c in disponibles)]
    if !isempty(faltants)
        error("Columns not found in the DataFrame: $faltants")
    end
    return select(df, columnes)
end




       
       function create_circuit_dataframe_direct(id_circuits, features_v, feature_names)
        
           # checking dimensions
           if length(id_circuits) != length(features_v)
               error("circuit names and features do not match")
           end

           # DataFrame
           df = DataFrame()
           df.circuit_name = id_circuits

           # filling it with features
           for (i, feature_name) in enumerate(feature_names)
               df[!, Symbol(feature_name)] = [feature_vector[i] for feature_vector in features_v]
           end

           return df
       end





function getting_candidate_plan(model,nom_v,features_v,feature_names,features_13; empat =false)
    
    df = create_circuit_dataframe_direct(nom_v, features_v,feature_names)
    columnes = append!(["circuit_name"],features_13)
    df_filtrat = selecciona_columnes(df, columnes)

    circuit_ids,predictions=Prediccions_X(model, df_filtrat)
    valors, posicions = maxims_i_posicions(predictions)
    
  if empat == false
        nom_complet = nom_v[posicions[1]]
        nom_circuit = split(nom_complet, "_pla_")[2]
        
    println("Our plan candidate : $(nom_circuit)")

    else
        println("Our plan candidates: ")
        for i in 1:length(posicions)
            nom_complet = nom_v[posicions[i]]
            nom_circuit = split(nom_complet, "_pla_")[2]
            println(nom_circuit)
        end
    end
    return 
end

function maxims_i_posicions(v)
    max_val = maximum(v)
    posicions = findall(==(max_val), v)
    valors = fill(max_val, length(posicions))
    return valors, posicions
end


# Individual prediction
function Prediu_Speedup(model,dades_features)
        
    # Converteix a matriu (1 observació, n característiques)
    X_new = reshape(dades_features, 1, :)
    
    # Fes la predicció
    prediction = XGBoost.predict(model, X_new)
    
    return prediction[1]
end


### Predictions in a grup

function Prediccions_X(model, df_circuits)
    
    circuit_ids= df_circuits.circuit_name
      
    predictions = Float64[]
    
    
    for id in 1:length(circuit_ids)
        
        dades_features = Vector{Float64}(df_circuits[id,Cols(2:14)])
        predicted_speedup = Prediu_Speedup(model,dades_features)
        
        push!(predictions, predicted_speedup)
        
    end
    
    
    return (circuit_ids=circuit_ids,predictions=predictions)
end
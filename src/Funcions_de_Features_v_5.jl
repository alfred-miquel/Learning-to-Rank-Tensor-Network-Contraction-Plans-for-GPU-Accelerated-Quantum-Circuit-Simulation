

# =============================================================================
# Funcions_de_Features.jl (versió millorada. Versió 5 del document de IA)
# =============================================================================
# Funcions relacionades amb el càlcul de features basat en les dades de 
# contraccions de tensors.
# =============================================================================

"""
    calcul_Ci_Pi_Di(contractions; epsilon=1.0e-6)

Calcula les tres mètriques bàsiques per a cada contracció:
- Ci: cost computacional (rankA + rankB - num_common_indices)
- Pi: paral·lelisme potencial (rankA + rankB - 2*num_common_indices)
- Di: desequilibri/asimetria (|rankA - rankB| / (Pi + epsilon))

Arguments:
- contractions: vector d'estructures amb camps .rankA, .rankB, .num_common_indices
- epsilon: constant per evitar divisió per zero

Retorna:
- Tupla (Ci, Pi, Di) on cada element és un vector de Float64
"""
function calcul_Ci_Pi_Di(contractions; epsilon=1.0e-6)
    n = length(contractions)
    Ci = Vector{Float64}(undef, n)
    Pi = Vector{Float64}(undef, n)
    Di = Vector{Float64}(undef, n)
    
    for i in 1:n
        ci = contractions[i].rankA + contractions[i].rankB - contractions[i].num_common_indices
        Ci[i] = ci
        
        pi = (contractions[i].rankA + contractions[i].rankB) - (2 * contractions[i].num_common_indices)
        Pi[i] = pi
        
        di = abs(contractions[i].rankA - contractions[i].rankB) / (pi + epsilon)
        Di[i] = di
    end
    
    return Ci, Pi, Di
end

"""
    calcul_Ci_Pi_Di_Ki(contractions; epsilon=1.0e-6)

Versió estesa que afegeix Ki (nombre d'índexs comuns / reducció)
"""
function calcul_Ci_Pi_Di_Ki(contractions; epsilon=1.0e-6)
    n = length(contractions)
    Ci = Vector{Float64}(undef, n)
    Pi = Vector{Float64}(undef, n)
    Di = Vector{Float64}(undef, n)
    Ki = Vector{Float64}(undef, n)
    
    for i in 1:n
        Ci[i] = contractions[i].rankA + contractions[i].rankB - contractions[i].num_common_indices
        Pi[i] = (contractions[i].rankA + contractions[i].rankB) - (2 * contractions[i].num_common_indices)
        Di[i] = abs(contractions[i].rankA - contractions[i].rankB) / (Pi[i] + epsilon)
        Ki[i] = contractions[i].num_common_indices
    end
    
    return Ci, Pi, Di, Ki
end

# =============================================================================
# Funcions auxiliars
# =============================================================================

"""
    tots_maxims(v)

Retorna el valor màxim d'un vector i totes les posicions on apareix.
"""
function tots_maxims(v)
    max_val = maximum(v)
    posicions = findall(x -> x == max_val, v)
    return max_val, posicions
end

"""
    valors_per_dalt_de(v; limit=0.9)

Retorna els elements del vector que superen un llindar.
"""
function valors_per_dalt_de(v; limit=0.9)
    posicions = findall(x -> x >= limit, v)
    quantitat = length(posicions)
    return limit, quantitat, posicions
end

"""
    mitjana_top_q_percent(v; q=5)

Calcula la mitjana del top q% dels valors més alts del vector.
"""
function mitjana_top_q_percent(v; q=5)
    v_ordenat = sort(v, rev=true)
    n = length(v)
    k = max(1, round(Int, n * q / 100))
    top_elements = v_ordenat[1:k]
    return mean(top_elements), top_elements
end

"""
    fracc_tiny_steps(Ci; tau=6)

F10: Fracció de passos "petits" on ci ≤ max(ci) - tau.
Indica quants passos estan molt per sota del coll d'ampolla.
"""
function fracc_tiny_steps(Ci; tau=6)
    max_cost = maximum(Ci)
    return sum(Ci .<= (max_cost - tau)) / length(Ci)
end

# =============================================================================
# Features del coll d'ampolla (bottleneck)
# =============================================================================

"""
    coll_ampolla(Ci, Di, Pi)

Calcula mètriques relacionades amb el coll d'ampolla:
- max_cost_Ci: cost màxim
- max_imbalance_Di: desequilibri màxim
- P_at_maxC: paral·lelisme mitjà als punts de cost màxim
- D_at_maxC: desequilibri mitjà als punts de cost màxim
"""
function coll_ampolla(Ci, Di, Pi)
    max_cost_Ci = maximum(Ci)
    posicions_max = findall(==(max_cost_Ci), Ci)
    max_imbalance_Di = maximum(Di)
    
    P_at_maxC = sum(Pi[posicions_max]) / length(posicions_max)
    D_at_maxC = sum(Di[posicions_max]) / length(posicions_max)
    
    return max_cost_Ci, max_imbalance_Di, P_at_maxC, D_at_maxC
end

"""
    coll_ampolla_ampliada(Ci, Di, Pi)

Versió ampliada que afegeix topq_mean_C.
"""
function coll_ampolla_ampliada(Ci, Di, Pi)
    max_cost_Ci = maximum(Ci)
    posicions_max = findall(==(max_cost_Ci), Ci)
    max_imbalance_Di = maximum(Di)
    
    P_at_maxC = sum(Pi[posicions_max]) / length(posicions_max)
    D_at_maxC = sum(Di[posicions_max]) / length(posicions_max)
    topq_mean_C, _ = mitjana_top_q_percent(Ci)
    
    return max_cost_Ci, max_imbalance_Di, P_at_maxC, D_at_maxC, topq_mean_C
end

"""
    k_at_max_cost(Ci, Ki)

*** NOVA FUNCIÓ (FALTANT) ***
K at max cost: Mitjana de Ki (reduction rank) en els passos on ci és màxim.
Interpretació: Proxy d'intensitat aritmètica al coll d'ampolla.
"""
function k_at_max_cost(Ci, Ki)
    max_cost = maximum(Ci)
    posicions_max = findall(==(max_cost), Ci)
    return mean(Ki[posicions_max])
end

# =============================================================================
# Features ponderades per cost (cost-weighted)
# =============================================================================

"""
    cost_w_P(Ci, Pi)

Cost-weighted out-rank: Σ (Pi * 2^Ci) / Σ 2^Ci
"""
function cost_w_P(Ci, Pi)
    pesos = 2.0 .^ Ci
    return sum(Pi .* pesos) / sum(pesos)
end

"""
    cost_w_D(Ci, Di)

Cost-weighted asymmetry: Σ (Di * 2^Ci) / Σ 2^Ci
"""
function cost_w_D(Ci, Di)
    pesos = 2.0 .^ Ci
    return sum(Di .* pesos) / sum(pesos)
end

"""
    cost_w_K(Ci, Ki)

Cost-weighted reduction rank: Σ (Ki * 2^Ci) / Σ 2^Ci
"""
function cost_w_K(Ci, Ki)
    pesos = 2.0 .^ Ci
    return sum(Ki .* pesos) / sum(pesos)
end

# =============================================================================
# Features d'asimetria (asymmetry)
# =============================================================================

"""
    max_asym(Di)

*** NOVA FUNCIÓ (FALTANT) ***
Maximum asymmetry (maxi di) del pla.
Interpretació: Pitjor desequilibri de contracció (skinny vs square).
"""
function max_asym(Di)
    return maximum(Di)
end

"""
    cost_w_asym(Ci, Di)

*** NOVA FUNCIÓ (FALTANT) ***
Cost-weighted asymmetry: Σ (Di * 2^Ci) / Σ 2^Ci
Interpretació: Desequilibri de forma a la regió cara del pla.
"""
function cost_w_asym(Ci, Di)
    pesos = 2.0 .^ Ci
    return sum(Di .* pesos) / sum(pesos)
end

# =============================================================================
# Altres features
# =============================================================================

"""
    log_2_sum_flops(Ci)

F2: log2(Σ 2^ci) - Proxy del total de FLOPS logarítmics.
"""
function log_2_sum_flops(Ci)
    return log2(sum(2.0 .^ Ci))
end

"""
    max_red_rank(Ki)

F5: Maximum reduction rank (maxi ki)
"""
function max_red_rank(Ki)
    return maximum(Ki)
end

# =============================================================================
# Funcions principals d'extracció de features
# =============================================================================

using Statistics

"""
    get_features_v2(contractions)

Extreu totes les features segons la versió 2 del document.
"""
function get_features_v2(contractions)
    Ci, Pi, Di = calcul_Ci_Pi_Di(contractions)
    max_cost_Ci, max_imbalance_Di, P_at_maxC, D_at_maxC, topq_mean_C = coll_ampolla_ampliada(Ci, Di, Pi)
    cost_weighted_P = cost_w_P(Ci, Pi)
    cost_weighted_D = cost_w_D(Ci, Di)
    
    N_steps = length(contractions)
    avg_cost_Ci = sum(Ci) / N_steps
    avg_parallelism_Pi = sum(Pi) / N_steps
    avg_imbalance_Di = sum(Di) / N_steps
    
    std_C = std(Ci)
    max_parallelism_Pi = maximum(Pi)
    
    return [max_cost_Ci, max_imbalance_Di, P_at_maxC, D_at_maxC, topq_mean_C,
            cost_weighted_P, cost_weighted_D, avg_cost_Ci, avg_parallelism_Pi,
            avg_imbalance_Di, std_C, N_steps, max_parallelism_Pi]
end

"""
    get_features_v5(contractions)

Extreu totes les features segons la versió 5 del document (taula completa).
Inclou TOTES les 18 features de la taula.
"""
function get_features_v5(contractions)
    # Càlcul de mètriques bàsiques
    Ci, Pi, Di, Ki = calcul_Ci_Pi_Di_Ki(contractions)
    
    # Features de complexitat / coll d'ampolla (6 features)
    max_cost = maximum(Ci)                                    # max cost
    log2_sum_flops_val = log_2_sum_flops(Ci)                  # log2 sum flops
    topq_mean, _ = mitjana_top_q_percent(Ci)                  # topq mean cost
    avg_cost = mean(Ci)                                       # avg cost
    std_cost = std(Ci)                                        # std cost
    n_steps = length(Ci)                                      # n steps
    frac_tiny = fracc_tiny_steps(Ci)                          # frac tiny steps
    
    # Features de paral·lelisme (5 features)
    max_out_rank = maximum(Pi)                                # max out rank
    avg_out_rank = mean(Pi)                                   # avg out rank
    costw_out_rank = cost_w_P(Ci, Pi)                         # costw out rank
    p_at_max_cost_val = coll_ampolla(Ci, Di, Pi)[3]           # p at max cost
    
    # Features de reducció / intensitat (3 features)
    max_red_rank_val = max_red_rank(Ki)                       # max red rank
    costw_red_rank_val = cost_w_K(Ci, Ki)                     # costw red rank
    k_at_max_cost_val = k_at_max_cost(Ci, Ki)                 # k at max cost (NOVA)
    
    # Features de geometria / memòria (4 features)
    max_asym_val = max_asym(Di)                               # max asym (NOVA)
    avg_asym = mean(Di)                                       # avg asym
    costw_asym_val = cost_w_asym(Ci, Di)                      # costw asym (NOVA)
    d_at_max_cost_val = coll_ampolla(Ci, Di, Pi)[4]           # d at max cost
    
    # Vector amb les 18 features en l'ordre de la taula
    features = [
        max_cost,              # 1. max cost
        log2_sum_flops_val,    # 2. log2 sum flops
        topq_mean,             # 3. topq mean cost
        avg_cost,              # 4. avg cost
        std_cost,              # 5. std cost
        n_steps,               # 6. n steps
        frac_tiny,             # 7. frac tiny steps
        max_out_rank,          # 8. max out rank
        avg_out_rank,          # 9. avg out rank
        costw_out_rank,        # 10. costw out rank
        p_at_max_cost_val,     # 11. p at max cost
        max_red_rank_val,      # 12. max red rank
        costw_red_rank_val,    # 13. costw red rank
        k_at_max_cost_val,     # 14. k at max cost (NOVA)
        max_asym_val,          # 15. max asym (NOVA)
        avg_asym,              # 16. avg asym
        costw_asym_val,        # 17. costw asym (NOVA)
        d_at_max_cost_val      # 18. d at max cost
    ]
    
    return features
end

# =============================================================================
# Funcions d'entrada/sortida
# =============================================================================

"""
    extraure_nom_circuit(nom_arxiu::String)::String

Extreu el nom del circuit d'un nom d'arxiu amb format "resultats_NOM.txt".
"""
function extraure_nom_circuit(nom_arxiu::String)::String
    patro = r"^resultats_(.+)\.txt$"
    coincidencia = match(patro, nom_arxiu)
    
    if coincidencia !== nothing
        return coincidencia.captures[1]
    elseif startswith(nom_arxiu, "resultats_") && endswith(nom_arxiu, ".txt")
        return nom_arxiu[11:end-4]
    else
        return nom_arxiu
    end
end

"""
    get_contractions(filename)

Llegeix un fitxer i retorna les contraccions.
"""
#function get_contractions(filename)
    # Nota: cal tenir definida read_contractions_analisi_ranks_indexs
#    contractions, _, _, _, _, _, _, _ = read_contractions_analisi_ranks_indexs(filename, verbose=false)
 #   return contractions
#end

function get_contractions(filename)


    contractions,comptador,ranks_A,ranks_B,ranks_C,ranks_AB,ranks_AB_d,Zeros = read_contractions_analisi_ranks_indexs(filename,verbose=false);

 return contractions

end

# nolint start: trailing_whitespace_linter, object_name_linter, object_usage_linter, line_length_linter, return_linter, identation_linter.
library(ggplot2)
library(scales)

if (basename(getwd()) == "output") setwd("..")
if (dir.exists("teste-de-benchmark")) setwd("teste-de-benchmark")

dir_entrada  <- "output"
dir_saida    <- "saida_R"
dir_graficos <- "graficos_R"

dir.create(dir_saida, recursive = TRUE, showWarnings = FALSE)
dir.create(dir_graficos, recursive = TRUE, showWarnings = FALSE)

entrada <- function(arquivo) file.path(dir_entrada, arquivo)
saida <- function(arquivo) file.path(dir_saida, arquivo)
saida_grafico <- function(arquivo) file.path(dir_graficos, arquivo)

# =====================================================================
# 2. METODOLOGIA
# =====================================================================

data_InsertionSort_omega <- read.csv(
  entrada("Time_InsertionSort_Omega.csv"), sep = ";"
)
data_InsertionSort_theta <- read.csv(
  entrada("Time_InsertionSort_Theta.csv"), sep = ";"
)
data_InsertionSort_bigO  <- read.csv(
  entrada("Time_InsertionSort_BigO.csv"),  sep = ";"
)

data_MergeSort_omega <- read.csv(entrada("Time_MergeSort_Omega.csv"), sep = ";")
data_MergeSort_theta <- read.csv(entrada("Time_MergeSort_Theta.csv"), sep = ";")
data_MergeSort_bigO  <- read.csv(entrada("Time_MergeSort_BigO.csv"),  sep = ";")


calc_estatisticas <- function(data, nome_arquivo) {
  v_size <- unique(data$size)
  medias <- numeric(length(v_size))
  desvio <- numeric(length(v_size))
  epm    <- numeric(length(v_size))
  ic_min <- numeric(length(v_size))
  ic_max <- numeric(length(v_size))
  minimo <- numeric(length(v_size))
  maximo <- numeric(length(v_size))
  
  
  for (j in seq_along(v_size)) {
    
    tempos <- data$evaluated_time[data$size == v_size[j]]
    
    medias[j] <- mean(data$evaluated_time[data$size == v_size[j]])
    desvio[j] <- sd(data$evaluated_time[data$size == v_size[j]])
    
    epm[j] <- desvio[j] / sqrt(length(tempos))
    
    margem_erro <- qt(0.975, df = (length(tempos) - 1))*epm[j]
    
    ic_min[j] <- medias[j] - margem_erro
    ic_max[j] <- medias[j] + margem_erro
    
    minimo[j] <- min(tempos)
    maximo[j] <- max(tempos)
  }
  
  rm(j)
  rm(margem_erro)
  
  df <- data.frame(v_size, medias, desvio, ic_min, ic_max, minimo, maximo)
  colnames(df) <- c(
    "Tamanho", "Media", "Desvio_Padrao",
    "IC_Inferior", "IC_Superior", "Valor_Minimo", "Valor_Maximo"
  )
  write.csv(df, saida(nome_arquivo), row.names = FALSE)
  
}

for (i in c("omega", "theta", "bigO")) {
  calc_estatisticas(
    get(paste0("data_InsertionSort_", i)),
    paste0("stats_InsertionSort_", i, ".csv")
  )
  calc_estatisticas(
    get(paste0("data_MergeSort_", i)),
    paste0("stats_MergeSort_", i, ".csv")
  )
  assign(paste0("stats_InsertionSort_", i),
         read.csv(saida(paste0("stats_InsertionSort_", i, ".csv"))))

  assign(paste0("stats_MergeSort_", i),
         read.csv(saida(paste0("stats_MergeSort_", i, ".csv"))))
}

rm(data_InsertionSort_omega, data_InsertionSort_theta, data_InsertionSort_bigO,
   data_MergeSort_omega, data_MergeSort_theta, data_MergeSort_bigO)

conjuntos <- list(
  insertion_omega = stats_InsertionSort_omega,
  insertion_theta = stats_InsertionSort_theta,
  insertion_bigO  = stats_InsertionSort_bigO,
  merge_omega     = stats_MergeSort_omega,
  merge_theta     = stats_MergeSort_theta,
  merge_bigO      = stats_MergeSort_bigO)


polyreg <- function(stats, grau) {
  
  df <- data.frame(tamanho = stats$Tamanho, media = stats$Media)
  
  modelo <- lm(media ~ poly(tamanho, grau, raw = TRUE), data=df)
  
  return(list(modelo = modelo))
}

ajuste_mergesort_teorico <- function(stats) {
  df <- data.frame(tamanho = stats$Tamanho, media = stats$Media)
  
  modelo <- lm(media ~ I(tamanho*log(tamanho)) + tamanho, data=df)
  
  return(list(modelo = modelo))
}


melhor_grau <- function(stats) {
  stats_capado <- subset(stats, Tamanho < 100000)
  reais <- subset(stats, Tamanho >= 100000)
  
  erros <- numeric(4)
  
  for (grau in 1:4) {
    
    modelo <- polyreg(stats_capado, grau)$modelo
    pred <- predict(modelo, newdata = data.frame(tamanho = reais$Tamanho))
    
    erros[grau] <- mean(abs((reais$Media - pred) / reais$Media))
    
  }
  
  melhor <- which.min(erros)
  
  return(melhor)
}


# =====================================================================
# 3. RESULTADOS
# =====================================================================

gerar_graficos <- function(tab1, tab2, nome_tabela, nome_arquivo){
  
  rotulos <- c("1k", "2k", "5k", "10k", "20k", "50k", "100k", "200k", "500k", "1M")
  
  dados <- rbind(
    data.frame(Tamanho = rotulos, Media = tab1$Media, IC_min = tab1$IC_Inferior,
               IC_max = tab1$IC_Superior, Algoritmo = "Insertion Sort"),
    data.frame(Tamanho = rotulos, Media = tab2$Media, IC_min = tab2$IC_Inferior,
               IC_max = tab2$IC_Superior, Algoritmo = "Merge Sort"))
  
  dados$Tamanho <- factor(dados$Tamanho, levels = rotulos)
  
  piso <- 1e-8
  
  grafico <- ggplot(
    dados, aes(Tamanho, log10(Media / piso), fill = Algoritmo)
  ) +
    geom_col(position = position_dodge(0.9), color = "black", linewidth = 0.2) +
    
    geom_errorbar(aes(ymin = log10(IC_min / piso),
                      ymax = log10(IC_max / piso)),
                  position = position_dodge(0.9),
                  width = 0.5)+

    scale_y_continuous(breaks = 0:ceiling(max(log10(dados$Media / piso))),
      limits = c(0, ceiling(max(log10(dados$Media / piso))) + 1),
      labels = function(y) label_number(drop0trailing = TRUE)(piso * 10^y)) +

    labs(title = nome_tabela, x = "Tamanho (n)", y = "Tempo (s)",
         caption = "") +
    scale_fill_manual(values = c("steelblue", "coral")) +
    theme_minimal()
  ggsave(saida_grafico(nome_arquivo),
    plot = grafico, # nolint: indentation_linter.
    width = 15,
    height = 9,
    dpi = 300)
}

gerar_graficos(stats_InsertionSort_omega, stats_MergeSort_omega,
               "Média de tempo de execução - Melhor Caso",
               "grafico_omega.png")

gerar_graficos(stats_InsertionSort_theta, stats_MergeSort_theta,
               "Média de tempo de execução - Médio Caso",
               "grafico_theta.png")

gerar_graficos(stats_InsertionSort_bigO, stats_MergeSort_bigO,
 "Média de tempo de execução - Pior Caso", # nolint: indentation_linter.
 "grafico_bigO.png")


# =====================================================================
# 4. ANÁLISE
# =====================================================================

razao_dobro <- function(stats) {
  de   <- c(1, 3, 4, 6, 7, 9)
  para <- c(2, 4, 5, 7, 8, 10)
  r <- stats$Media[para] / stats$Media[de]
  names(r) <- paste0(stats$Tamanho[de], "->", stats$Tamanho[para])
  round(r, 2)
}

razaodobro <- do.call(rbind, lapply(conjuntos, razao_dobro))

razaodobro <- as.data.frame(razaodobro)

write.csv(razaodobro, saida("Razao_Dobro.csv"))


n_base <- stats_InsertionSort_omega$Tamanho[c(1, 3, 4, 6, 7, 9)]
round(2 * log(2 * n_base) / log(n_base), 2)




# Tabela 8
mais_rapido <- rbind(
  Melhor = ifelse(
    stats_InsertionSort_omega$Media < stats_MergeSort_omega$Media,
    "Insertion", "Merge"
  ),
  Medio  = ifelse(
    stats_InsertionSort_theta$Media < stats_MergeSort_theta$Media,
    "Insertion", "Merge"
  ),
  Pior   = ifelse(
    stats_InsertionSort_bigO$Media  < stats_MergeSort_bigO$Media,
    "Insertion", "Merge"
  )
)

colnames(mais_rapido) <- stats_InsertionSort_omega$Tamanho
write.csv2(mais_rapido, saida("tabela_mais_rapido.csv"), quote = FALSE)


for (cen in c("omega", "theta", "bigO")) {
  ins <- get(paste0("stats_InsertionSort_", cen))
  mer <- get(paste0("stats_MergeSort_", cen))

  sobrepoe <- !(
    ins$IC_Superior < mer$IC_Inferior | mer$IC_Superior < ins$IC_Inferior
  )
  cat(
    cen, ": ICs sobrepostos em", sum(sobrepoe),
    "de", length(sobrepoe), "tamanhos\n"
  )
}


med <- lapply(conjuntos, function(s) s$Media)

razao_ins_mer <- rbind(
  Melhor = med$insertion_omega / med$merge_omega, # nolint: indentation_linter.
  Medio  = med$insertion_theta / med$merge_theta,
  Pior   = med$insertion_bigO  / med$merge_bigO)
colnames(razao_ins_mer) <- stats_InsertionSort_omega$Tamanho

signif(razao_ins_mer, 3)
# Crescimento da razão entre 1.000 e 1.000.000 (texto: ~400x médio, ~780x pior;
# esperado por n/log n: ~500x)
round(razao_ins_mer[, 10] / razao_ins_mer[, 1])


# ---------------------------------------------------------------------
# 4.3 Diferença entre cenários (razões citadas no texto)
# ---------------------------------------------------------------------
razao_cenarios <- rbind(
  "Insertion medio/melhor" = med$insertion_theta / med$insertion_omega, # nolint
  "Insertion pior/melhor"  = med$insertion_bigO  / med$insertion_omega,
  "Insertion pior/medio"   = med$insertion_bigO  / med$insertion_theta,
  "Merge medio/melhor"     = med$merge_theta     / med$merge_omega,
  "Merge pior/melhor"      = med$merge_bigO      / med$merge_omega)
colnames(razao_cenarios) <- stats_InsertionSort_omega$Tamanho

signif(razao_cenarios, 3)


# ---------------------------------------------------------------------
# 4.4 Regressão polinomial
# ---------------------------------------------------------------------

# Modelos finais: grau escolhido por melhor_grau para cada algoritmo e cenário
for (i in c("omega", "theta", "bigO")) {
  assign(
    paste0("modelo_Insertion_", i),
    polyreg(
      get(paste0("stats_InsertionSort_", i)),
      melhor_grau(get(paste0("stats_InsertionSort_", i)))
    )$modelo
  )
  
  assign(
    paste0("modelo_Merge_", i),
    polyreg(
      get(paste0("stats_MergeSort_", i)),
      melhor_grau(get(paste0("stats_MergeSort_", i)))
    )$modelo
  )
}

nomes <- c(
  "Insertion, melhor", "Insertion, médio", "Insertion, pior",
  "Merge, melhor", "Merge, médio", "Merge, pior"
)

# Erro de extrapolação (%) dos graus 1 a 3 e do modelo n log n (Tabela 10)
erro_extrapolado <- function(stats) {
  stats_capado <-  subset(stats, Tamanho < 100000)
  reais <- subset(stats, Tamanho >= 100000)
  
  erros <- numeric(4)
  nomes <- c("grau 1", "grau 2", "grau 3", "n log(n)")
  
  for (grau in 1:3){
    modelo <- polyreg(stats_capado, grau)$modelo
    pred <- predict(modelo, newdata = data.frame(tamanho = reais$Tamanho))
    erros[grau] <- mean(abs((reais$Media - pred) / reais$Media))
  }
  
  modelo <- ajuste_mergesort_teorico(stats_capado)$modelo
  pred <- predict(modelo, newdata = data.frame(tamanho = reais$Tamanho))
  erros[4] <- mean(abs((reais$Media - pred) / reais$Media))
  
  names(erros) <- nomes
  return(round(100 * erros, 2))
}

# Tabela 9 - funções obtidas
modelos <- mget(c(paste0("modelo_Insertion_", c("omega", "theta", "bigO")),
                  paste0("modelo_Merge_", c("omega", "theta", "bigO"))))

coefs <- t(sapply(modelos, function(m) { 
  b <- coef(m); length(b) <- 3; b })) # nolint: semicolon_linter, indentation_linter.
tab9 <- matrix(
  formatC(coefs, format = "E", digits = 5, decimal.mark = ","),
  nrow = 6
)
tab9[is.na(coefs)] <- "-"
tab9 <- data.frame(
  nomes,
  Grau = sapply(modelos, function(m) length(coef(m)) - 1),
  tab9
)
colnames(tab9) <- c(
  "Cenário", "Grau", "Intercepto", "Coef. de n", "Coef. de n²"
)
write.csv2(tab9, saida("tabela_funcoes.csv"), row.names = FALSE)

# Tabela 10 - erro de extrapolação (%);
tab10 <- t(sapply(conjuntos, erro_extrapolado))
tab10[1:3, "n log(n)"] <- NA
tab10 <- data.frame(
  Cenário = nomes,
  tab10,
  Escolhido = sapply(conjuntos, melhor_grau),
  check.names = FALSE
)
write.csv2(tab10, saida("tabela_erros.csv"), row.names = FALSE, na = "-")


coef(modelo_Insertion_bigO)[3] / coef(modelo_Insertion_theta)[3]


coef(modelo_Merge_omega)[3] * 1e6^2 / (coef(modelo_Merge_omega)[2] * 1e6)


n_positivo <- function(m) {
  n <- 1:20000
  min(n[predict(m, newdata = data.frame(tamanho = n)) > 0])
}
sapply(modelos, n_positivo)


teoricos_merge <- list(
  melhor = ajuste_mergesort_teorico(stats_MergeSort_omega)$modelo,
  medio  = ajuste_mergesort_teorico(stats_MergeSort_theta)$modelo,
  pior   = ajuste_mergesort_teorico(stats_MergeSort_bigO)$modelo
)

sapply(teoricos_merge, coef)    
sapply(teoricos_merge, function(m) coef(m)[2] * 1e6 * log(1e6))   
sapply(teoricos_merge, function(m) coef(m)[3] * 1e6)             


100 * (predict(modelo_Insertion_theta, newdata = data.frame(tamanho = 1000)) -
         stats_InsertionSort_theta$Media[1]) / stats_InsertionSort_theta$Media[1] # nolint: line_length_linter.


modelo_Merge_omega_teorico <- # nolint: object_name_linter.
  ajuste_mergesort_teorico(stats_MergeSort_omega)$modelo
modelo_Merge_theta_teorico <- # nolint: object_name_linter.
  ajuste_mergesort_teorico(stats_MergeSort_theta)$modelo
modelo_Merge_bigO_teorico  <- # nolint: object_name_linter.
  ajuste_mergesort_teorico(stats_MergeSort_bigO)$modelo

grafico_regressao <- function(
  stats, modelo, titulo, arquivo, cor, modelo_teorico = NULL
) {
  
  n <- seq(1000, 1000000, length.out = 300)     # faixa medida
  
  curvas <- data.frame(
    Tamanho = n,
    Tempo = predict(modelo, newdata = data.frame(tamanho = n)),
    Modelo = paste("Polinômio de grau", length(coef(modelo)) - 1)
  )
  
  if (!is.null(modelo_teorico)) {
    curvas <- rbind(
      curvas,
      data.frame(
        Tamanho = n,
        Tempo = predict(modelo_teorico, newdata = data.frame(tamanho = n)),
        Modelo = "a·n·log n + b·n + c"
      )
    )
  }
  
  grafico <- ggplot() +
    geom_line(
      data = curvas,
      aes(Tamanho, Tempo, linetype = Modelo),
      color = cor,
      linewidth = 0.8
    ) +
    geom_point(
      data = stats,
      aes(Tamanho, Media, shape = "Média medida"),
      size = 2.5
    ) +
    scale_x_continuous(
      labels = label_number(big.mark = ".", decimal.mark = ",")
    ) +
    scale_y_continuous(
      labels = label_number(big.mark = ".", decimal.mark = ",")
    ) +
    labs(
      title = titulo,
      x = "Tamanho (n)",
      y = "Tempo (s)",
      linetype = NULL,
      shape = NULL
    ) +
    theme_minimal()
  
  ggsave(
    saida_grafico(arquivo), plot = grafico, width = 10, height = 6, dpi = 300
  )
}

arquivos_regressao <- c("insertion_melhor", "insertion_medio", "insertion_pior",
                        "merge_melhor", "merge_medio", "merge_pior")
cores <- c(rep("steelblue", 3), rep("coral", 3))
teoricos <- list(
  NULL, NULL, NULL,
  modelo_Merge_omega_teorico,
  modelo_Merge_theta_teorico,
  modelo_Merge_bigO_teorico
)

for (k in 1:6){
  grafico_regressao(conjuntos[[k]], modelos[[k]],
                    paste("Regressão polinomial -", nomes[k]),
                    paste0("regressao_", arquivos_regressao[k], ".png"),
                    cores[k], teoricos[[k]])
}


cv <- stats_InsertionSort_theta$Desvio_Padrao /
  stats_InsertionSort_theta$Media * 100
cv_df <- data.frame(
  Tamanho = stats_InsertionSort_theta$Tamanho, CV = round(cv, 2)
)

rm(arquivos_regressao)
rm(cen)
rm(cores)
rm(cv)
rm(i)
rm(k)
rm(n_base)
rm(nomes)
rm(sobrepoe)
rm(coefs)
rm(conjuntos)
rm(ins)

#nolint end: trailing_whitespace_linter, object_name_linter, object_usage_linter, line_length_linter, return_linter, identation_linter.
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>
#include <limits.h>

void Insertion_Sort(int *A, int n){

    for(int i = 1; i < n; i++){
        int key = A[i];
        int j = i-1;

        while(j >= 0 && A[j] > key){
            A[j+1] = A[j];
            j = j-1;
        }
        A[j+1] = key;
    }

}

void merge(int *A, int p, int q, int r){

    int n1 = q - p + 1;
    int n2 = r - q;

    //int L[n1] , R[n2];
    int *L = malloc((n1 + 1) * sizeof(int));
    int *R = malloc((n2 + 1) * sizeof(int));
    
    int i,j,k;

    for(i = 0; i < n1; i++){
        L[i] = A[p + i];
    }

    for(j = 0; j < n2; j++){
        R[j] = A[q + 1 + j];
    }

    L[n1] = INT_MAX;
    R[n2] = INT_MAX;

    i = 0;
    j = 0;

    for(k = p; k <= r; k++){
        if(L[i] <= R[j]){
            A[k] = L[i];
            i++;
        }else{
            A[k] = R[j];
            j++;
        }
    }

    free(L);
    free(R);

}

void Merge_Sort(int *A, int p, int r){

    if (p < r){
        int q = (p + r) / 2;
        Merge_Sort(A, p, q);
        Merge_Sort(A, q + 1, r);
        merge(A, p, q, r);
    }

    
}

void benchmark(const char *nome_arquivo_insertion, const char *nome_arquivo_merge, int cenario){

    struct timespec start, end;

    int qtd[10] = {1000, 2000, 5000, 10000, 20000, 50000, 100000, 200000, 500000, 1000000};


        FILE *evaluated_time_file_insertion = fopen(nome_arquivo_insertion, "w");
        fprintf(evaluated_time_file_insertion, "run;size;evaluated_time\n");

        FILE *evaluated_time_file_merge = fopen(nome_arquivo_merge, "w");
        fprintf(evaluated_time_file_merge, "run;size;evaluated_time\n");

        for(int run = 1; run <= 50; run++){

            for(int i = 0; i < 10; i++){

                int n = qtd[i];
                int *A = malloc(sizeof(int) * n);
                int *B = malloc(sizeof(int) * n);

                if(cenario == 0){
                    for (int k = 0; k < n; k++) {
                        A[k] = k + 1;
                    }
                }else if(cenario == 1){
                    for (int k = 0; k < n; k++) {
                        A[k] = (rand() % 1000000) + 1;
                        //A[k] = k + 1;
                    }
                }else if(cenario == 2){
                    for (int k = 0; k < n; k++) {
                        A[k] = n - k;
                        //A[k] = k + 1;
                    }
                }

                memcpy(B, A, sizeof(int) * n);

                clock_gettime(CLOCK_MONOTONIC, &start);
                Insertion_Sort(A, n);
                clock_gettime(CLOCK_MONOTONIC, &end);
                free(A);

                double Tempo_medido_insertion;
                Tempo_medido_insertion = ((double)end.tv_sec + 1e-9 * end.tv_nsec) - ((double)start.tv_sec + 1e-9 * start.tv_nsec);

                printf("Insertion Sort - run %d | %d - %.9f\n", run, n, Tempo_medido_insertion);
                fprintf(evaluated_time_file_insertion, "%d;%d;%.9f\n", run, n, Tempo_medido_insertion);
                
                clock_gettime(CLOCK_MONOTONIC, &start);
                Merge_Sort(B, 0, n - 1);
                clock_gettime(CLOCK_MONOTONIC, &end);
                free(B);

                double Tempo_medido_merge;
                Tempo_medido_merge = ((double)end.tv_sec + 1e-9 * end.tv_nsec) - ((double)start.tv_sec + 1e-9 * start.tv_nsec);

                printf("Merge Sort - run %d | %d - %.9f\n", run, n, Tempo_medido_merge);
                fprintf(evaluated_time_file_merge, "%d;%d;%.9f\n", run, n, Tempo_medido_merge);
                

            }
        }
        fclose(evaluated_time_file_insertion);
        fclose(evaluated_time_file_merge);
}

int main(){
    srand(time(NULL));
    benchmark("Time_InsertionSort_Omega.csv", "Time_MergeSort_Omega.csv", 0);

    benchmark("Time_InsertionSort_Theta.csv", "Time_MergeSort_Theta.csv", 1);

    benchmark("Time_InsertionSort_BigO.csv", "Time_MergeSort_BigO.csv", 2);
    return 0;
}
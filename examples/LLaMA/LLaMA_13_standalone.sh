#!/bin/bash

DATASET="/workspace/project-dataset/bookcorpus_llama3_mega/bookcorpus_text_document"

# NODE_RANK=$1
NNODES=1

TP_SIZE=$1
PP_SIZE=$2
DP_SIZE=$3
echo "DP_SIZE is: $DP_SIZE"
MICRO_BATCH_SIZE=1
# The int is the number of micro steps of gradient accumulation
# GLOBAL_BATCH_SIZE=$((($WORLD_SIZE * $MICRO_BATCH_SIZE) / ($TP_SIZE * $PP_SIZE) ))
GLOBAL_BATCH_SIZE=$(($DP_SIZE * 4))

echo "GLOBAL_BATCH_SIZE is: $GLOBAL_BATCH_SIZE"

JOB_NAME="LLaMA_dp${DP_SIZE}_tp${TP_SIZE}_pp${PP_SIZE}_gbs${GLOBAL_BATCH_SIZE}"

# TOKENIZER_PATH="/data/haiqwa/zevin_nfs/andy/Auto-Parallelization/nnscaler_group1/qinghe/nnscaler-main/examples/llama3_8B_128K/llama3_mini"
TOKENIZER_PATH="/workspace/project-dataset/llama3-model/Meta-Llama-3-andy(20B)"

TRAIN_ITERS=30
EVAL_ITERS=10
EVAL_INTERVAL=1000
SAVE_INTERVAL=100
LOG_INTERVAL=1

export NCCL_SOCKET_IFNAME="eth0"
export GLOO_SOCKET_IFNAME="eth0"

# Setting --tensorboard-queue-size to 1 significantly slows down the training
options=" \
    --finetune \
    --sequence-parallel \
        --tensor-model-parallel-size ${TP_SIZE} \
        --pipeline-model-parallel-size ${PP_SIZE} \
    --num-layers 32 \
        --hidden-size 4096 \
        --num-attention-heads 32 \
        --seq-length 4096 \
        --max-position-embeddings 8192 \
        --use-rotary-position-embeddings \
        --swiglu \
        --ffn-hidden-size 14336\
        --disable-bias-linear \
        --RMSNorm \
        --layernorm-epsilon 1e-6 \
        --causal-lm \
    --tokenizer-type PretrainedFromHF \
        --tokenizer-name-or-path $TOKENIZER_PATH \
        --make-vocab-size-divisible-by 1 \
    --init-method-std 0.01 \
    --micro-batch-size ${MICRO_BATCH_SIZE} \
        --global-batch-size ${GLOBAL_BATCH_SIZE} \
    --train-iters ${TRAIN_ITERS} \
    --lr 6.0e-5 \
        --lr-decay-iters 10 \
        --lr-warmup-iters 5 \
        --min-lr 6.0e-6 \
        --override-opt_param-scheduler \
        --lr-decay-style cosine \
    --adam-beta1 0.9 \
        --adam-beta2 0.95 \
        --clip-grad 1.0 \
        --weight-decay 0.1 \
        --overlapped-distributed-optimizer \
        --reduce-bucket-size=2e8 \
        --no-gradient-accumulation-fusion \
    --dataloader-type cyclic \
        --data-impl mmap \
        --data-path ${DATASET} \
        --split 98,2,0 \
    --eval-interval ${EVAL_INTERVAL} \
        --eval-iters ${EVAL_ITERS} \
    --log-interval ${LOG_INTERVAL} \
        --tensorboard-queue-size 1000 \
        --log-timers-to-tensorboard \
        --log-batch-size-to-tensorboard \
        --log-validation-ppl-to-tensorboard \
    --job-name ${JOB_NAME} \
    --bf16 \
    --recompute-activations \
        --recompute-granularity selective \
    --use-flash-attn"

DTIME=`date +%m-%d`
MTIME=`date +%m-%d-%H-%M`
# torchrun --master_addr=$MASTER_ADDR --node_rank=$NODE_RANK --nnodes=${NNODES} --nproc_per_node=8 --master_port=29500 /workspace/project-code/Megatron-LLaMA/pretrain_llama.py ${options}
torchrun --nnodes=${NNODES} --nproc_per_node=8 --master_port=29500 /workspace/project-code/Megatron-LLaMA/pretrain_llama.py ${options} 2>&1 | tee logs/seq4k/${DTIME}/${MTIME}.${JOB_NAME}.log

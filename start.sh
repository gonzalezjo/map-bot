#!/bin/bash
parallel --lb -N0 luajit solver.lua ::: {1..$(nproc)} > outcomes.txt

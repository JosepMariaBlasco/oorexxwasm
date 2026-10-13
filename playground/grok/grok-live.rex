/******************************************************************************/
/*                                                                            */
/* grok-live.rex - grok.rex in the browser, drawing what happens as it trains */
/* ======================================================================     */
/*                                                                            */
/* Copyright (c) 2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>       */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Version history:                                                           */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20261013    0.1  First version, from grok.rex 0.4                          */
/*                                                                            */
/******************************************************************************/

--------------------------------------------------------------------------------
-- What this program adds to grok.rex                                         --
--------------------------------------------------------------------------------
--
-- The same network, data, seed and training as grok.rex 0.4 (the trace in the
-- console is the same, number for number), for ooRexx compiled to
-- WebAssembly: https://rexx.epbcn.com/oorexx-wasm/. While it trains, it draws
-- with ADDRESS JDOR (Rony G. Flatscher's drawing commands, on the browser's
-- canvas):
--
--   - the losses (log scale) and the accuracies, train and test, epoch by
--     epoch: memorising in tens of epochs, the long plateau, the jump;
--   - a spectrogram of the embeddings E: the share of their energy in each
--     Fourier frequency, over time. A network that groks ends up with its
--     energy in a few frequencies (with the defaults: k=5, 2 and 4);
--   - the whole table (a + b) mod p as the network answers it now, test
--     pairs framed: the train cells turn green first, the framed ones much
--     later;
--   - the energy of E by frequency, now, as bars.
--
-- The drawing is done by the browser worker that hosts the run, which never
-- blocks, while ooRexx computes in its own thread: the window refreshes
-- without any SLEEP.
--
-- Differences from grok.rex: no checkpoints (in the browser every run starts
-- from scratch; the ckptEvery and keepEvery arguments are ignored), and the
-- drawing routines at the end ("Drawing"). This file is generated from
-- grok.rex by live/build-live.py: change grok.rex, not this.
--
-- What follows is grok.rex 0.4, with its explanations.
--

--------------------------------------------------------------------------------
-- What this program does                                                     --
--------------------------------------------------------------------------------
--
-- Learns modular addition, (a + b) mod p, from examples, and shows the
-- learning happen: first it memorises the training pairs, and much later it
-- reorganises its weights and starts to get the unseen pairs right too. That
-- second event is called "grokking". The whole network, its training and its
-- instruments are in this file; the only outside help is the rxmath library.
--
-- Architecture (the smallest thing that groks):
--
--     a, b  --> E[a], E[b]   two embeddings of de numbers each
--           --> x = E[a] ++ E[b]                 din = 2*de inputs
--           --> z1 = W1*x + b1,  h = relu(z1)    dh hidden neurons
--           --> logits = W2*h + b2                p outputs
--           --> prob = softmax(logits)            one per residue
--
-- Training: cross-entropy loss, gradients by backpropagation, AdamW optimiser,
-- full batch (one step per epoch, with the gradient accumulated over all the
-- training pairs).
--
-- Representation: every matrix is an Array of column vectors, so that the code
-- can name things: E[a+1] is the embedding of the residue a, W1[j] is neuron j
-- (its din input weights), W2[k] is the read-out of class k (its dh weights
-- over the hidden layer). Residues and classes run 0..p-1, Rexx arrays start
-- at 1: hence the +1.
--

--------------------------------------------------------------------------------
-- 1. Parameters                                                              --
--------------------------------------------------------------------------------
--
-- Usage:
--
--    rexx grok.rex [wd] [epochs] [p] [testfrac] [dh] [lr] [ckptEvery] -
--                  [keepEvery] [de]
--
--    no arguments: wd=0.5 epochs=2000 p=13 testfrac=0.1 dh=32
--                  lr=0.02 ckptEvery=200 keepEvery=0 de=12
--                  (the minimal example: 1385 parameters, 153 train pairs,
--                  16 test pairs. Memorises by epoch 50, groks at epoch 950,
--                  under three minutes on a small PC)
--    examples:     rexx grok.rex 0.5 2000 13 0.1 48 0.02 200 200 16
--                  (a bigger network, 2429 parameters: groks at epoch 800;
--                  with lr=0.003 and wd=1.0 instead, the same network groks
--                  at epoch 2800: same phenomenon, three times slower)
--                  rexx grok.rex 0.5 10000 17 0.2 128 0.003 200 1000
--
-- If a checkpoint for the configuration is found, training RESUMES from it
-- (section 4): to watch a run from the start, delete it or use a new
-- directory.
--
-- The checkpoint file and the columns of the trace are described where they
-- are produced (sections 4 and 5).
--

Parse Arg argWd argEpochs argP argTf argDh argLr argCk argKeep argDe .

p         = 13        -- modulus: p*p possible pairs

de        = 12        -- size of each embedding
dh        = 32        -- neurons in the hidden layer
lr        = 0.02      -- learning rate (one step per epoch). Higher is
                      -- faster, up to a point: at 0.003 few seeds grok
                      -- at all, at 0.02 nearly all of them do, and at
                      -- 0.03 some go astray
wd        = 0.5       -- decoupled weight decay. Too low: |W| never falls
                      -- and the network keeps its memorised list. Too
                      -- high: train drops from 100% and does not recover
epochs    = 2000      -- memorises in tens, groks in hundreds
testfrac  = 0.1       -- fraction of the pairs held out: 0.1 -> 153 train /
                      -- 16 test for p=13
ckptEvery = 200       -- save the checkpoint every ckptEvery epochs
keepEvery = 0         -- >0: also keep a numbered copy every keepEvery epochs

If argWd     \== "" Then wd        = argWd
If argLr     \== "" Then lr        = argLr
If argCk     \== "" Then ckptEvery = argCk
If argKeep   \== "" Then keepEvery = argKeep
If argEpochs \== "" Then epochs    = argEpochs
If argP      \== "" Then p         = argP
If argTf     \== "" Then testfrac  = argTf
If argDh     \== "" Then dh        = argDh
If argDe     \== "" Then de        = argDe
din = 2 * de          -- the MLP input: the two embeddings side by side

beta1     = 0.9       -- Adam: memory of the gradient (momentum)
beta2     = 0.98      -- Adam: memory of the squared gradient
eps       = 1e-8      -- Adam: keeps the division away from zero

-- Same seed => same numbers, to the last decimal, on every run.

seed      = 12345

-- We want deterministic sequences. The RANDOM BIF only gives reproducible
-- results when running in the same code body (see section 2).

Call Random ,, seed

Signal SkipOverUniform

Uniform: Return Random(0,2000)/1000 - 1

SkipOverUniform: Nop

--------------------------------------------------------------------------------
-- 2. Data                                                                    --
--------------------------------------------------------------------------------
--
-- All p*p pairs (a, b) with their answer y = (a + b) mod p, in a fixed order:
-- pair number a*p + b + 1. A random testfrac of them is held out as TEST: the
-- network never trains on those, they only measure whether it has learnt the
-- rule or the list.
--
-- (The split and the initial weights below are drawn in the main program,
-- and Uniform is an internal routine: in ooRexx the seeded Random() sequence
-- is shared by a program and its internal routines, but a ::Routine gets a
-- generator of its own, unseeded, and a new one on every call.)

nPairs = p * p
pairA  = .Array~new(nPairs)
pairB  = .Array~new(nPairs)
pairY  = .Array~new(nPairs)
isTest = .Array~new(nPairs)~fill(0)
k = 0
Loop a = 0 To p-1
  Loop b = 0 To p-1
    k = k + 1
    pairA[k] = a
    pairB[k] = b
    pairY[k] = (a + b) // p
  End
End

nTest = 0
Loop While nTest < Trunc(nPairs * testfrac)
  k = Random(1, nPairs)
  If isTest[k] = 0 Then Do
    isTest[k] = 1
    nTest = nTest + 1
  End
End
nTrain = nPairs - nTest

trainIdx = .Array~new       -- pair numbers of the training pairs
testIdx  = .Array~new       -- pair numbers of the test pairs
Loop k = 1 To nPairs
  If isTest[k] Then testIdx~append(k)
  Else              trainIdx~append(k)
End

--------------------------------------------------------------------------------
-- 3. The network                                                             --
--------------------------------------------------------------------------------
--
-- Five parameter blocks. Initial values uniform in [-1, 1], scaled: embeddings
-- by 0.5, W1 by 1/sqrt(din), W2 by 1/sqrt(dh) (so that the sums in the forward
-- pass start at order 1). Biases at zero. The loops run in the order of the
-- original program (rows outside, columns inside) so that each weight gets the
-- same random number.

net = .Directory~new
net~E  = NewMatrix(p,  de)  -- E[a+1] : embedding of residue a
net~W1 = NewMatrix(dh, din) -- W1[j]  : input weights of neuron j
net~b1 = NewVector(dh)      -- b1[j]  : bias of neuron j
net~W2 = NewMatrix(p,  dh)  -- W2[k]  : read-out weights of class k
net~b2 = NewVector(p)       -- b2[k]  : bias of class k

sc1 = 1 / Sqrt(din)
sc2 = 1 / Sqrt(dh)
Loop n = 0 To p-1
  emb = net~E[n+1]
  Loop j = 1 To de
    emb[j] = Uniform() * 0.5
  End
End
Loop i = 1 To din
  Loop j = 1 To dh
    net~W1[j][i] = Uniform() * sc1
  End
End
Loop i = 1 To dh
  Loop k = 1 To p
    net~W2[k][i] = Uniform() * sc2
  End
End

-- Gradient accumulators and Adam moments: one per parameter block, same
-- shapes, all zero. m is the running mean of the gradient, v the running mean
-- of its square; Adam divides one by the root of the other, so that every
-- coordinate moves by about lr per step.

grad  = SameShape(net)
adamM = SameShape(net)
adamV = SameShape(net)

-- Scratch space for one forward/backward pass (allocated once).

act = .Directory~new
act~x       = NewVector(din) -- input: the two embeddings
act~z1      = NewVector(dh)  -- hidden layer before the ReLU
act~h       = NewVector(dh)  -- hidden layer after the ReLU
act~logits  = NewVector(p)   -- one score per class
act~prob    = NewVector(p)   -- softmax of the scores
act~dLogits = NewVector(p)   -- d loss / d logits
act~dHidden = NewVector(dh)  -- d loss / d h
act~dZ1     = NewVector(dh)  -- d loss / d z1
act~dX      = NewVector(din) -- d loss / d x

--------------------------------------------------------------------------------
-- 4. Checkpoint                                                              --
--------------------------------------------------------------------------------
--
-- Every ckptEvery epochs (and at the end) the weights, the Adam moments and
-- the counters go to a text file named after the structural configuration,
-- grok-p13-tf0.1-de12-dh32-s12345.ckpt. If it exists at start-up, training
-- RESUMES from it; delete it to start from scratch. lr and wd are not part of
-- the name: they can be changed when resuming. The train/test split comes from
-- the seed, so it is the same one. With keepEvery > 0, a numbered copy
-- (...-4000.ckpt) is kept every keepEvery epochs, starting with the initial
-- weights (...-0.ckpt), to study later how the network keeps reorganising
-- after it has reached 100%.

ep0 = 0
t   = 0                     -- Adam step counter (for the bias corrections)

nParams = p*de + din*dh + dh + dh*p + p
Say "# parameters:" nParams
Say "# pairs:" nPairs "  train:" nTrain "  test:" nTest "  (p="p")"
Say "epochs="epochs "  lr="lr "  wd="wd "  de="de "  dh="dh -
    "  optim=AdamW full-batch  digits="Digits()
Say "no checkpoints in the browser version: every run starts from scratch"
-- The trace, and what to look at in each column. train_loss goes to ~0 in a
-- few dozen epochs (memorisation) and train_acc to 100%. test_loss is the
-- continuous view of generalisation (test_acc is a staircase, one step per
-- test pair, and hides the slow movement of the margins). margin is the
-- smallest margin over the test pairs: negative, some test pair is wrong;
-- around zero, the network is on the edge; comfortably positive, it has
-- grokked. |W| rises while memorising; grokking arrives when it STARTS TO FALL
-- with train at 100%. energy is the share of the energy of E in its two
-- dominant Fourier frequencies (random: ~15% each for p=13; grokked: one or
-- two with most of it): it shows reorganisation long before test_acc moves.

Say ""
Say "epoch |  train_loss  train_acc |  test_loss  test_acc  margin |" || -
    "   |W|    |   sec | energy of E by frequency"
Say "------+--------------------------+----------------------------+" || -
    "----------+-------+-------------------------"

--------------------------------------------------------------------------------
-- 5. Training                                                                --
--------------------------------------------------------------------------------
--
-- One epoch = one pass over the training pairs, accumulating the gradient of
-- the loss with respect to every parameter, followed by ONE AdamW step with the
-- mean gradient.

hyper = .Directory~new
hyper~lr     = lr
hyper~wd     = wd
hyper~beta1  = beta1
hyper~beta2  = beta2
hyper~eps    = eps
hyper~nTrain = nTrain

plot = PlotSetup(p, epochs, isTest, nTrain, nTest, lr, wd, de, dh)
grokEp = 0                  -- first epoch with every test pair right

t0 = Time("E")

Loop ep = ep0+1 To epochs
  sumLoss  = 0
  nCorrect = 0
  Call Clear grad

  Loop idx = 1 To nTrain
    k = trainIdx[idx]
    a = pairA[k]
    b = pairB[k]
    y = pairY[k]

    Call ForwardPass net, a, b, act
    prob = act~prob
    sumLoss = sumLoss - Ln(prob[y+1] + 1e-12)      -- cross-entropy
    If ArgMax(prob) - 1 = y Then nCorrect = nCorrect + 1

    Call BackwardPass net, grad, a, b, y, act
  End

  t = t + 1
  Call AdamWStep net, grad, adamM, adamV, t, hyper

  trainLoss = sumLoss / nTrain
  trainAcc  = nCorrect / nTrain
  If ep // plot~every = 0 | ep = 1 | ep = epochs Then Do
    test = Evaluate(net, act, pairA, pairB, pairY, testIdx)
    Call PlotPoint plot, ep, trainLoss, trainAcc, test~loss, test~acc
    If test~acc = 1 & grokEp = 0 Then Do
      grokEp = ep
      Call PlotGrokked plot, ep
    End
    Call PlotStatus plot, ep, trainAcc, test~acc, WeightNorm(net), -
                    Time("E") - t0, grokEp
  End
  If ep // plot~specEvery = 0 | ep = 1 | ep = epochs Then
    Call PlotSpectrum plot, ep, FourierShares(net~E)
  If ep // plot~gridEvery = 0 | ep = 1 | ep = epochs Then
    Call PlotGrid plot, net, act, isTest
  If ShouldReport(ep, epochs) Then Do
    trainAcc = nCorrect / nTrain
    test = Evaluate(net, act, pairA, pairB, pairY, testIdx)
    Say Right(ep,5) "  " Format(sumLoss/nTrain,,6) " "                        -
        Format(trainAcc*100,4,1)"%   |  " Format(test~loss,,6) " "            -
        Format(test~acc*100,4,1)"% " Signed(test~margin,3,2) "|"              -
        Format(WeightNorm(net),4,3) " |" Format(Time("E")-t0,6,0) "|"         -
        FourierEnergy(net~E)
  End
End
Say ""
Say "training:" Format(Time("E")-t0,,1) "s"
Call PlotDone plot, grokEp, Time("E") - t0

--------------------------------------------------------------------------------
-- 6. Final table                                                             --
--------------------------------------------------------------------------------

Say ""
Say "Table (row a, column b). In [ ] = TEST pair (never seen)."
header = "     "
Loop b = 0 To p-1
  header = header Center(b,4)
End
Say header
okAll  = 1
okTest = 1
Loop a = 0 To p-1
  line = "a="a":"
  Loop b = 0 To p-1
    got = Predict(net, a, b, act)
    ok  = (got = (a + b) // p)
    If \ok Then okAll = 0
    If isTest[a*p + b + 1] Then Do
      If \ok Then okTest = 0
      cell = "["got"]"
    End
    Else cell = " "got" "
    line = line cell
  End
  Say line
End
Say ""
Say "train:" nTrain "pairs    test:" nTest "pairs"
If okAll       Then Say "*** PERFECT: every pair right, seen and unseen."
Else If okTest Then Say "*** Generalises: every TEST pair (unseen) right."
Else Say "Does not fully generalise: some test pair fails (wrong [x] cells)."

Exit

::Requires "jdor.cls"         -- ADDRESS JDOR: drawing on the browser's canvas

/******************************************************************************/
/*                                                                            */
/* Shapes                                                                     */
/*                                                                            */
/******************************************************************************/

-- A vector of n zeros.

::Routine NewVector
  Use Strict Arg n
  Return .Array~new(n)~fill(0)

-- A matrix as an Array of nCols column vectors of nRows zeros. m[j] is column
-- j, m[j][i] its i-th component.

::Routine NewMatrix
  Use Strict Arg nCols, nRows
  m = .Array~new(nCols)
  Loop j = 1 To nCols
    m[j] = NewVector(nRows)
  End
  Return m

-- A directory with the same blocks and shapes as net, all zero.

::Routine SameShape
  Use Strict Arg net
  d = .Directory~new
  Loop name Over net~allIndexes
    block = net[name]
    If IsMatrix(block) Then d[name] = NewMatrix(block~size, block[1]~size)
    Else                    d[name] = NewVector(block~size)
  End
  Return d

-- Set every number in every block of d to zero.

::Routine Clear
  Use Strict Arg d
  Loop block Over d~allItems
    If IsMatrix(block) Then Do
      Loop col Over block
        col~fill(0)
      End
    End
    Else block~fill(0)
  End
  Return

-- A block is a matrix when its elements are vectors.

::Routine IsMatrix
  Use Strict Arg block
  Return block[1]~isA(.Array)

-- Index of the largest component (the first one, on ties).

::Routine ArgMax
  Use Strict Arg v
  best = 1
  vMax = v[1]
  Loop i = 2 To v~size
    If v[i] > vMax Then Do
      vMax = v[i]
      best = i
    End
  End
  Return best

/******************************************************************************/
/*                                                                            */
/* Forward pass                                                               */
/*                                                                            */
/******************************************************************************/

-- From the pair (a, b) to a probability for each of the p classes. Leaves in
-- act everything the backward pass will need.

::Routine ForwardPass
  Use Strict Arg net, a, b, act
  E  = net~E
  W1 = net~W1
  b1 = net~b1
  W2 = net~W2
  b2 = net~b2
  x      = act~x
  z1     = act~z1
  h      = act~h
  logits = act~logits
  prob   = act~prob
  de  = E[1]~size
  din = x~size
  dh  = W1~size
  p   = W2~size

  -- The input: the two embeddings, side by side

  ea = E[a+1]
  eb = E[b+1]
  Loop j = 1 To de
    x[j]    = ea[j]
    x[de+j] = eb[j]
  End

  -- Hidden layer: neuron j computes a weighted sum of the input, adds its
  -- bias, and fires (passes the value on) only if the result is positive

  Loop j = 1 To dh
    w   = W1[j]
    acc = b1[j]
    Loop i = 1 To din
      acc = acc + x[i] * w[i]
    End
    z1[j] = acc
    If acc > 0 Then h[j] = acc
    Else            h[j] = 0
  End

  -- Output layer: class k scores the hidden layer with its weights

  Loop k = 1 To p
    w   = W2[k]
    acc = b2[k]
    Loop i = 1 To dh
      acc = acc + h[i] * w[i]
    End
    logits[k] = acc
  End

  -- Softmax: exponentiate and normalise (subtracting the maximum first
  -- changes nothing mathematically and avoids overflow)

  mx = logits[1]
  Loop k = 2 To p
    If logits[k] > mx Then mx = logits[k]
  End
  denom = 0
  Loop k = 1 To p
    prob[k] = Exp(logits[k] - mx)
    denom   = denom + prob[k]
  End
  Loop k = 1 To p
    prob[k] = prob[k] / denom
  End
  Return

/******************************************************************************/
/*                                                                            */
/* Backward pass                                                              */
/*                                                                            */
/******************************************************************************/

-- Backpropagation: the derivative of the loss with respect to every parameter,
-- ACCUMULATED into grad (full batch: the caller adds the pairs up and takes one
-- step at the end).
--
-- The chain rule, layer by layer, backwards. For softmax followed by
-- cross-entropy the first step is famous for its simplicity:
--
--     d loss / d logits[k] = prob[k] - [k is the right class]
--
-- that is, "what you predicted minus what it was". From there every layer
-- passes the blame to the one before it:
--
--     y = W*x + b    =>   dW = dy * x,   db = dy,   dx = W' * dy
--     h = relu(z)    =>   dz = dh where z > 0, else 0

::Routine BackwardPass
  Use Strict Arg net, grad, a, b, y, act
  W1  = net~W1
  W2  = net~W2
  gE  = grad~E
  gW1 = grad~W1
  gb1 = grad~b1
  gW2 = grad~W2
  gb2 = grad~b2
  x       = act~x
  z1      = act~z1
  h       = act~h
  prob    = act~prob
  dLogits = act~dLogits
  dHidden = act~dHidden
  dZ1     = act~dZ1
  dX      = act~dX
  de  = gE[1]~size
  din = x~size
  dh  = W1~size
  p   = W2~size

  -- Output: predicted minus true

  Loop k = 1 To p
    dLogits[k] = prob[k]
  End
  dLogits[y+1] = dLogits[y+1] - 1

  -- Output layer: blame W2 and b2, and pass it down to h

  dHidden~fill(0)
  Loop k = 1 To p
    g      = dLogits[k]
    gb2[k] = gb2[k] + g
    w  = W2[k]
    gw = gW2[k]
    Loop i = 1 To dh
      dHidden[i] = dHidden[i] + g * w[i]
      gw[i]      = gw[i] + g * h[i]
    End
  End

  -- ReLU: a neuron that did not fire gets no blame

  Loop j = 1 To dh
    If z1[j] > 0 Then dZ1[j] = dHidden[j]
    Else              dZ1[j] = 0
  End

  -- Hidden layer: blame W1 and b1, and pass it down to x

  dX~fill(0)
  Loop j = 1 To dh
    g = dZ1[j]
    If g = 0 Then Iterate       -- nothing to accumulate
    gb1[j] = gb1[j] + g
    w  = W1[j]
    gw = gW1[j]
    Loop i = 1 To din
      dX[i] = dX[i] + g * w[i]
      gw[i] = gw[i] + g * x[i]
    End
  End

  -- Embeddings: the first half of dX belongs to E[a], the second to E[b]

  ga = gE[a+1]
  gb = gE[b+1]
  Loop j = 1 To de
    ga[j] = ga[j] + dX[j]
    gb[j] = gb[j] + dX[de+j]
  End
  Return

/******************************************************************************/
/*                                                                            */
/* AdamW step                                                                 */
/*                                                                            */
/******************************************************************************/

-- One step of AdamW with the MEAN gradient over the training pairs. Adam
-- keeps, per coordinate, a running mean of the gradient (m) and of its square
-- (v), and moves by lr * m / sqrt(v): every coordinate moves about lr per
-- step, whatever the size of its gradient. The bias corrections undo the zero
-- start of m and v. Weight decay is DECOUPLED: the weights are first shrunk by
-- (1 - lr*wd), then the Adam step is added. It applies to E, W1 and W2, not to
-- the biases.

::Routine AdamWStep
  Use Strict Arg net, grad, adamM, adamV, t, hyper
  lr = hyper~lr
  step = .Directory~new
  step~stepc = lr / (1 - hyper~beta1**t)          -- lr with bias correction
  step~rbc2  = 1 / Sqrt(1 - hyper~beta2**t)       -- bias correction of v
  step~inv   = 1 / hyper~nTrain                   -- sum -> mean gradient
  step~decay = 1 - lr * hyper~wd
  step~beta1 = hyper~beta1
  step~beta2 = hyper~beta2
  step~eps   = hyper~eps
  Loop name Over .Array~of("E", "W1", "W2")       -- matrices: decayed
    cols = net[name]
    g    = grad[name]
    m    = adamM[name]
    v    = adamV[name]
    Loop j = 1 To cols~size
      Call AdamWVector cols[j], g[j], m[j], v[j], step, 1
    End
  End
  Loop name Over .Array~of("B1", "B2")            -- biases: not decayed
    Call AdamWVector net[name], grad[name], adamM[name], adamV[name], step, 0
  End
  Return

-- The step itself, on one vector w with its gradient sum g and moments m, v
-- (all updated in place).

::Routine AdamWVector
  Use Strict Arg w, g, m, v, step, decayed
  stepc = step~stepc
  rbc2  = step~rbc2
  inv   = step~inv
  decay = step~decay
  beta1 = step~beta1
  beta2 = step~beta2
  eps   = step~eps
  Loop i = 1 To w~size
    gi   = g[i] * inv
    m[i] = beta1*m[i] + (1-beta1)*gi
    v[i] = beta2*v[i] + (1-beta2)*gi*gi
    If decayed Then w[i] = w[i] * decay - stepc * m[i] / (Sqrt(v[i])*rbc2 + eps)
    Else            w[i] = w[i]         - stepc * m[i] / (Sqrt(v[i])*rbc2 + eps)
  End
  Return

/******************************************************************************/
/*                                                                            */
/* Instruments                                                                */
/*                                                                            */
/******************************************************************************/

-- The class predicted for the pair (a, b): 0..p-1.

::Routine Predict
  Use Strict Arg net, a, b, act
  Call ForwardPass net, a, b, act
  Return ArgMax(act~logits) - 1

-- Loss, accuracy and minimum margin over a set of pairs (by pair number). The
-- margin of a pair is the score of the right class minus the best of the
-- others: positive means right, and its size says by how much.

::Routine Evaluate
  Use Strict Arg net, act, pairA, pairB, pairY, idxs
  logits = act~logits
  prob   = act~prob
  sumLoss   = 0
  nOk       = 0
  minMargin = ""
  Loop k Over idxs
    y = pairY[k]
    Call ForwardPass net, pairA[k], pairB[k], act
    sumLoss = sumLoss - Ln(prob[y+1] + 1e-12)
    If ArgMax(logits) - 1 = y Then nOk = nOk + 1
    other = ""
    Loop c = 1 To logits~size
      If c = y+1 Then Iterate
      If other == "" | logits[c] > other Then other = logits[c]
    End
    margin = logits[y+1] - other
    If minMargin == "" | margin < minMargin Then minMargin = margin
  End
  res = .Directory~new
  n = idxs~size
  If n > 0 Then Do
    res~loss = sumLoss / n
    res~acc  = nOk / n
  End
  Else Do
    res~loss = 0
    res~acc  = 0
  End
  res~margin = minMargin
  Return res

-- Euclidean norm of the decayed weights (E, W1, W2).

::Routine WeightNorm
  Use Strict Arg net
  ss = 0
  Loop name Over .Array~of("E", "W1", "W2")
    Loop col Over net[name]
      Loop i = 1 To col~size
        ss = ss + col[i] * col[i]
      End
    End
  End
  Return Sqrt(ss)

-- Energy of the embeddings by Fourier frequency. Each of the de coordinates
-- of E is a sequence of p numbers (one per residue). Its DFT over the residue
-- axis splits it into frequencies k = 0..p-1; by Parseval the total energy is
-- preserved, so the share of each frequency is exact. k=0 is the mean (dc);
-- k and p-k are mirror images and are added together. Returns the two
-- dominant frequencies, formatted for the trace.

::Routine FourierEnergy
  Use Strict Arg E
  p  = E~size
  de = E[1]~size
  cosT = FourierTable(p, "cos")
  sinT = FourierTable(p, "sin")
  energy = .Array~new(p)                          -- energy[k+1]: frequency k
  tot = 0
  Loop k = 0 To p-1
    ck = cosT[k+1]
    sk = sinT[k+1]
    pk = 0
    Loop j = 1 To de
      re = 0
      im = 0
      Loop n = 0 To p-1
        en = E[n+1][j]
        re = re + en * ck[n+1]
        im = im + en * sk[n+1]
      End
      pk = pk + re*re + im*im
    End
    energy[k+1] = pk
    tot = tot + pk
  End
  If tot = 0 Then Return "(E is zero)"
  half = (p-1) % 2
  F = .Array~new(half)                            -- F[k]: frequencies k and p-k
  Loop k = 1 To half
    F[k] = energy[k+1] + energy[p-k+1]
  End
  k1 = 1
  Loop k = 2 To half
    If F[k] > F[k1] Then k1 = k
  End
  k2 = 0
  Loop k = 1 To half
    If k = k1 Then Iterate
    If k2 = 0 Then k2 = k
    Else If F[k] > F[k2] Then k2 = k
  End
  Return "k="k1 Format(100*F[k1]/tot,3,0)"%" -
         " k="k2 Format(100*F[k2]/tot,3,0)"%" -
         " dc" Format(100*energy[1]/tot,3,0)"%"

-- cos or sin of 2*pi*k*n/p, as an Array of p rows (k) of p values (n).
-- Computed once and kept in .local.

::Routine FourierTable
  Use Strict Arg p, fn
  key = "grok.fourier."fn"."p
  If .local~hasIndex(key) Then Return .local[key]
  tab = .Array~new(p)
  Loop k = 0 To p-1
    row = .Array~new(p)
    Loop n = 0 To p-1
      angle = 360 * k * n / p                     -- rxmath works in degrees
      If fn == "cos" Then row[n+1] = Cos(angle)
      Else                row[n+1] = Sin(angle)
    End
    tab[k+1] = row
  End
  .local[key] = tab
  Return tab

-- A number with its sign, right-aligned: sign, up to `before` integer digits,
-- the point, `after` decimals.

::Routine Signed
  Use Strict Arg x, before, after
  txt = Format(x,, after)
  If x >= 0 Then txt = "+"txt
  Return Right(txt, before + after + 2)

-- Report often at the start, rarely later.

::Routine ShouldReport
  Use Strict Arg e, eMax
  If e = 1 | e = eMax Then Return 1
  If e <= 200  Then Return (e // 10 = 0)
  If e <= 2000 Then Return (e // 50 = 0)
  Return (e // 200 = 0)

/******************************************************************************/
/*                                                                            */
/* Drawing (ADDRESS JDOR)                                                     */
/*                                                                            */
/******************************************************************************/

-- One window of 1000x640. Left, on a common time axis (epochs 0..epochs):
-- losses, accuracies, spectrogram of E. Right: the table as the network
-- answers it now, and the energy of E by frequency now. Coordinates are
-- pixels, (0,0) at the top left; JDOR wants integers, hence the Format(...,,0).
-- Every routine says ADDRESS JDOR: the environment is selected per routine.

::Routine PlotSetup
  Use Strict Arg p, epochs, isTest, nTrain, nTest, lr, wd, de, dh
  Address jdor
  pl = .Directory~new
  pl~p = p
  pl~epochs = epochs
  pl~W = 1000
  pl~H = 640
  pl~x0 = 70                         -- time axis: x0 .. x0+pw
  pl~pw = 560
  pl~lossY = 100; pl~lossH = 180     -- losses, log scale 1e-6 .. 10
  pl~accY  = 315; pl~accH  = 110     -- accuracies, 0 .. 100%
  pl~half  = (p-1) % 2               -- frequencies k = 1 .. half
  pl~rowH  = 144 % pl~half
  pl~specY = 460; pl~specH = pl~rowH * pl~half
  pl~gx0 = 700; pl~gy0 = 100         -- the table
  pl~cell = Min(20, 270 % p)
  pl~bx0 = 700; pl~bw = 280          -- the bars, bottom aligned with the spectrogram
  pl~every     = Max(1, (epochs + pl~pw - 1) % pl~pw)    -- about one pixel per point
  pl~specEvery = 5 * pl~every
  pl~gridEvery = 10 * pl~every
  pl~lastEp = ""                     -- the previous point, to draw segments
  pl~lastSpecX = pl~x0

  "newImage" pl~W pl~H
  "winTitle grok.rex: a network learns (a + b) mod" p
  "color cGrid 228 228 228"
  "color cAxis 150 150 150"
  "color cText 40 40 40"
  "color cSoft 110 110 110"
  "color cTrain 31 119 180"
  "color cTest 230 110 20"
  "color cGrok 200 30 60"
  "color okTrain 188 224 188"
  "color badTrain 244 196 196"
  "color okTest 40 160 70"
  "color badTest 214 48 48"
  "color cFrame 25 25 25"
  "color cBar 8 48 107"
  "font fTitle SansSerif bold 18"
  "font fBold SansSerif bold 13"
  "font fText SansSerif plain 12"
  "font fSmall SansSerif plain 10"
  "stroke thin 1"
  "stroke thick 2"

  "color white"; "moveTo 0 0"; "fillRect" pl~W pl~H
  "color cText"; "font fTitle"; "moveTo 20 30"
  "drawString A network learns (a + b) mod" p "- grok.rex, in ooRexx, in the browser"
  "color cSoft"; "font fText"; "moveTo 20 50"
  "drawString" nTrain "train pairs,"  nTest "test pairs (never trained on)  ·  embeddings" -
    de", hidden" dh"  ·  AdamW lr="lr "wd="wd"  ·  full batch, one step per epoch"

  x0 = pl~x0; x1 = x0 + pl~pw
  -- vertical grid lines: every quarter of the run, in all three panels
  "stroke thin"
  Loop q = 0 To 4
    x = PlotX(pl, epochs * q / 4)
    "color cGrid"
    "moveTo" x pl~lossY; "drawLine" x pl~lossY + pl~lossH
    "moveTo" x pl~accY;  "drawLine" x pl~accY + pl~accH
    "color cSoft"; "font fSmall"
    lab = Format(epochs * q / 4,,0)
    "moveTo" x - 3 * Length(lab) pl~specY + pl~specH + 16
    "drawString" lab
  End
  "moveTo" x1 - 30 pl~specY + pl~specH + 30; "drawString epoch"

  -- losses
  "color cText"; "font fBold"; "moveTo" x0 pl~lossY - 8; "drawString loss (log scale)"
  labs = .Array~of("10", "1", "0.1", "0.01", "1e-3", "1e-4", "1e-5", "1e-6")
  Loop i = 1 To 8
    y = PlotLossY(pl, 10 ** (2 - i))
    "color cGrid"; "moveTo" x0 y; "drawLine" x1 y
    "color cSoft"; "font fSmall"; "moveTo" x0 - 8 - 5 * Length(labs[i]) y + 4
    "drawString" labs[i]
  End
  Call PlotLegend pl, x1 - 140, pl~lossY - 8

  -- accuracies
  "color cText"; "font fBold"; "moveTo" x0 pl~accY - 8; "drawString accuracy"
  Loop v Over .Array~of(0, 50, 100)
    y = PlotAccY(pl, v / 100)
    "color cGrid"; "moveTo" x0 y; "drawLine" x1 y
    "color cSoft"; "font fSmall"; "moveTo" x0 - 12 - 5 * Length(v) y + 4
    "drawString" v"%"
  End
  Call PlotLegend pl, x1 - 140, pl~accY - 8

  -- spectrogram
  "color cText"; "font fBold"; "moveTo" x0 pl~specY - 8
  "drawString energy of E by Fourier frequency, over time (darker = more)"
  "font fSmall"; "color cSoft"
  Loop k = 1 To pl~half
    "moveTo" x0 - 32 pl~specY + (k-1) * pl~rowH + pl~rowH % 2 + 4
    "drawString k="k
  End
  "color cAxis"; "stroke thin"
  "moveTo" x0 pl~specY; "drawRect" pl~pw pl~specH

  -- the table
  gx0 = pl~gx0; gy0 = pl~gy0; c = pl~cell
  "color cText"; "font fBold"; "moveTo" gx0 - 30 gy0 - 8
  "drawString the network's table of (a + b) mod" p", now"
  "font fSmall"; "color cSoft"
  Loop n = 0 To p-1
    "moveTo" gx0 + n * c + c % 2 - 3 * Length(n) gy0 + p * c + 12
    "drawString" n
    "moveTo" gx0 - 6 - 6 * Length(n) gy0 + n * c + c % 2 + 4
    "drawString" n
  End
  "moveTo" gx0 + p * c + 6 gy0 + p * c + 12; "drawString b"
  "moveTo" gx0 - 20 gy0 + p * c + 12; "drawString a"
  ly = gy0 + p * c + 30
  items = .Array~of("okTrain train, right", "badTrain train, wrong", -
                    "okTest test, right", "badTest test, wrong")
  Loop i = 1 To items~size
    Parse Value items[i] With col text
    lx = gx0 - 20 + ((i-1) // 2) * 140
    yy = ly + ((i-1) % 2) * 18
    "color" col; "moveTo" lx yy; "fillRect 12 12"
    If col~pos("Test") > 0 Then Do
      "color cFrame"; "stroke thin"; "drawRect 11 11"
    End
    "color cText"; "font fText"; "moveTo" lx + 18 yy + 11; "drawString" text
  End

  -- the bars
  "color cText"; "font fBold"; "moveTo" pl~bx0 - 20 pl~specY - 8
  "drawString energy of E by frequency, now"

  "winShow"
  Return pl

-- The legend of the train and test lines.

::Routine PlotLegend
  Use Strict Arg pl, x, y
  Address jdor
  "stroke thick"
  "color cTrain"; "moveTo" x y - 4; "drawLine" x + 18 y - 4
  "color cText"; "font fText"; "moveTo" x + 22 y; "drawString train"
  "color cTest"; "moveTo" x + 70 y - 4; "drawLine" x + 88 y - 4
  "color cText"; "moveTo" x + 92 y; "drawString test"

-- Pixel coordinates.

::Routine PlotX
  Use Strict Arg pl, ep
  Return Format(pl~x0 + ep * pl~pw / pl~epochs,,0)

::Routine PlotLossY
  Use Strict Arg pl, loss
  v = Max(1e-6, Min(10, loss))
  l10 = Ln(v) / Ln(10)                           -- -6 .. 1
  Return Format(pl~lossY + (1 - l10) / 7 * pl~lossH,,0)

::Routine PlotAccY
  Use Strict Arg pl, acc
  Return Format(pl~accY + (1 - acc) * pl~accH,,0)

-- One point of the four curves: a segment from the previous one.

::Routine PlotPoint
  Use Strict Arg pl, ep, trLoss, trAcc, teLoss, teAcc
  Address jdor
  x  = PlotX(pl, ep)
  y1 = PlotLossY(pl, trLoss); y2 = PlotLossY(pl, teLoss)
  y3 = PlotAccY(pl, trAcc);   y4 = PlotAccY(pl, teAcc)
  If pl~lastEp \== "" Then Do
    Parse Value pl~last With px py1 py2 py3 py4
    "stroke thick"
    "color cTest"
    "moveTo" px py2; "drawLine" x y2
    "moveTo" px py4; "drawLine" x y4
    "color cTrain"
    "moveTo" px py1; "drawLine" x y1
    "moveTo" px py3; "drawLine" x y3
  End
  pl~lastEp = ep
  pl~last = x y1 y2 y3 y4

-- The moment every test pair is right: a line across the three panels.

::Routine PlotGrokked
  Use Strict Arg pl, ep
  Address jdor
  x = PlotX(pl, ep)
  "color cGrok"; "stroke thin"
  "moveTo" x pl~lossY; "drawLine" x pl~specY + pl~specH
  "font fBold"; "moveTo" x + 5 pl~accY + pl~accH - 8
  "drawString grokked: epoch" ep

-- The status line under the title.

::Routine PlotStatus
  Use Strict Arg pl, ep, trAcc, teAcc, wn, secs, grokEp
  Address jdor
  "color white"; "moveTo 0 56"; "fillRect" pl~W 22
  txt = "epoch" ep "/" pl~epochs "     train" Format(trAcc*100,,1)"%" -
        "    test" Format(teAcc*100,,1)"%     |W|" Format(wn,,2)       -
        "    " Format(secs,,0) "s"
  "color cText"; "font fBold"; "moveTo 20 72"; "drawString" txt
  If grokEp > 0 Then Do
    "color cGrok"; "moveTo 560 72"; "drawString grokked at epoch" grokEp
  End

::Routine PlotDone
  Use Strict Arg pl, grokEp, secs
  Address jdor
  "color white"; "moveTo 540 56"; "fillRect" pl~W - 540 22
  "font fBold"; "moveTo 560 72"
  If grokEp > 0 Then Do
    "color cGrok"
    "drawString grokked at epoch" grokEp" · done in" Format(secs,,0) "s"
  End
  Else Do
    "color cText"
    "drawString did not grok in" pl~epochs "epochs"
  End

-- One column of the spectrogram (since the previous one) and the bars.
-- shares[k]: share of the energy of E in frequency k (and p-k).

::Routine PlotSpectrum
  Use Strict Arg pl, ep, shares
  Address jdor
  x = PlotX(pl, ep)
  w = Max(1, x - pl~lastSpecX)
  Loop k = 1 To pl~half
    t = Min(1, shares[k] / 0.4) ** 2             -- 40% or more: darkest
    r = Format(247 + t * (8 - 247),,0)
    g = Format(251 + t * (48 - 251),,0)
    b = Format(255 + t * (107 - 255),,0)
    "color sp" r g b
    "moveTo" pl~lastSpecX pl~specY + (k-1) * pl~rowH; "fillRect" w pl~rowH
  End
  pl~lastSpecX = x

  -- the bars: clear their area, then one bar per frequency
  y0 = pl~specY; h = pl~specH
  "color white"; "moveTo" pl~bx0 - 20 y0; "fillRect" pl~bw + 20 h + 20
  "color cGrid"; "stroke thin"
  "moveTo" pl~bx0 y0 + h; "drawLine" pl~bx0 + pl~bw y0 + h
  slot = pl~bw % pl~half
  Loop k = 1 To pl~half
    bh = Format(Min(1, shares[k]) * h,,0)
    bx = pl~bx0 + (k-1) * slot + 6
    "color cBar"; "moveTo" bx y0 + h - bh; "fillRect" slot - 12 bh
    "color cSoft"; "font fSmall"
    "moveTo" bx + 2 y0 + h + 14; "drawString k="k
    "color cText"; "moveTo" bx y0 + h - bh - 4
    "drawString" Format(shares[k] * 100,,0)"%"
  End

-- The table as the network answers it now. Test cells are framed.

::Routine PlotGrid
  Use Strict Arg pl, net, act, isTest
  Address jdor
  p = pl~p; c = pl~cell
  "winUpdate" .false                             -- show the table when complete
  Loop a = 0 To p-1
    Loop b = 0 To p-1
      ok = (Predict(net, a, b, act) = (a + b) // p)
      test = isTest[a*p + b + 1]
      Select
        When  test &  ok Then "color okTest"
        When  test        Then "color badTest"
        When  ok          Then "color okTrain"
        Otherwise              "color badTrain"
      End
      "moveTo" pl~gx0 + b * c pl~gy0 + a * c; "fillRect" c - 1 c - 1
    End
  End
  "color cFrame"; "stroke thick"
  Loop a = 0 To p-1
    Loop b = 0 To p-1
      If isTest[a*p + b + 1] Then Do
        "moveTo" pl~gx0 + b * c pl~gy0 + a * c; "drawRect" c - 2 c - 2
      End
    End
  End
  "winUpdate" .true

-- The share of the energy of E in each frequency pair (k, p-k), k = 1..half,
-- as in FourierEnergy (whose result is a string for the trace).

::Routine FourierShares
  Use Strict Arg E
  p  = E~size
  de = E[1]~size
  cosT = FourierTable(p, "cos")
  sinT = FourierTable(p, "sin")
  energy = .Array~new(p)
  tot = 0
  Loop k = 0 To p-1
    ck = cosT[k+1]
    sk = sinT[k+1]
    pk = 0
    Loop j = 1 To de
      re = 0
      im = 0
      Loop n = 0 To p-1
        en = E[n+1][j]
        re = re + en * ck[n+1]
        im = im + en * sk[n+1]
      End
      pk = pk + re*re + im*im
    End
    energy[k+1] = pk
    tot = tot + pk
  End
  half = (p-1) % 2
  shares = .Array~new(half)~fill(0)
  If tot = 0 Then Return shares
  Loop k = 1 To half
    shares[k] = (energy[k+1] + energy[p-k+1]) / tot
  End
  Return shares

/******************************************************************************/
/*                                                                            */
/* Mathematics from rxmath, under friendlier names                            */
/*                                                                            */
/******************************************************************************/

::Routine Sqrt External "LIBRARY rxmath RxCalcSqrt"
::Routine Exp  External "LIBRARY rxmath RxCalcExp"
::Routine Ln   External "LIBRARY rxmath RxCalcLog"
::Routine Cos  External "LIBRARY rxmath RxCalcCos"
::Routine Sin  External "LIBRARY rxmath RxCalcSin"

-- Decimal arithmetic with 10 significant digits, everywhere in this file:
-- float32, the usual currency of neural networks, has about 7. Fewer digits
-- would be faster.

::Options Digits 10

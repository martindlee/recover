* this is a sample to show removal of Trace code from displayed memos in a screen.
Public MemoTrace
use sample
scatter memvar memo
m.notes = MemoGet(m.notes)
do sample.spr

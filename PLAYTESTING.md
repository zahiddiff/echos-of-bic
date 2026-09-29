# Playtesting Echoes of BIC

Thanks for helping. There are two kinds of session, and it helps a lot if each tester does only one of them.

| Session | What to do | What I'm looking for |
|---|---|---|
| **Blind** | Play with no help beyond the controls. Don't read about the game first. Try for at least three shifts. | Does it get tense? When? Do you notice when something is off? |
| **Realism** | Play one or two shifts, paying attention to how normal it all feels. | Anything that feels fake, gamey or out of place: people, paperwork, the building, the job. |

## How

1. Open **[zahiddiff.github.io/echos-of-bic/?playtest](https://zahiddiff.github.io/echos-of-bic/?playtest)** (the `?playtest` part matters).
2. Play normally. After each shift you get two quick questions. Answer honestly, or skip them.
3. When you're done, press `Esc` and click **Save playtest log**. The same button is on the final screen.
4. Send me the downloaded `echoes-of-bic-playtest-….json` file.

Running the desktop version instead? Start it with `--playtest`. The button opens the folder the logs are in.

## What the log contains

For each visitor: the type of request, whether anything was wrong with it, what you decided, how long it took, and whether you used the magnifier, a follow-up question or the records terminal. For each shift: how it ended, how long it took, and your answers to the two questions.

It does **not** contain your name or anything else about you. Nothing is sent anywhere; the file only leaves your computer if you send it.

## Reading the logs

Put all the `.json` files in one folder and run:

```
godot --headless --path . --script res://tools/playtest_report.gd -- path/to/logs
```

This writes `report.md` into that folder. The report compares miss rate, false flags, paperwork mistakes, time per visitor and shift length against targets in `code/game/playtest_analysis.gd`, breaks the results down by shift, threat type and kind of paperwork problem, suggests which balance constants to change, and lists everything testers wrote.

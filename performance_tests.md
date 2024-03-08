## Dev perf tools & process

This page describes some performance testing tools used to "quickly" test NetObserv. That comes in addition to the [QE perf tests](https://github.com/openshift-qe/ocp-qe-perfscale-ci), which are more designed for large scale cluster & long running scenarios.

The tests use [hey-ho](https://github.com/jotak/hey-ho), a small wrapper on top of [hey](https://github.com/rakyll/hey) that deploys workloads on a running cluster and generates traffic. Start by cloning the hey-ho repo.

Test results are copied into [this spreadsheet](https://docs.google.com/spreadsheets/d/1qakBaK1dk_rERO30k1cSR4W-Nn0SXW4A3lqQ1sZC4rE/edit). Filling this spreadsheet is a manual process (but it doesn't take that long).
- Cells with light yellow background are informative: testbed, cluster info, promQL queries to get metrics, etc.
- Each run is displayed as a wide table with 3 scenarios mentionned: LOW, MEDIUM and HIGH. Each scenario correspond to a hey-ho command.
- Runs can be compared with each other. The second line in each scenario, showing percentages, shows comparisons with the selected baseline.
- Cells that are meant to be edited have a light purple background.

### Pre-requisite

- A running k8s / OpenShift cluster
- NetObserv operator installed

### Process

1. Edit the [results spreadsheet](https://docs.google.com/spreadsheets/d/1qakBaK1dk_rERO30k1cSR4W-Nn0SXW4A3lqQ1sZC4rE/edit) (or clone it if you prefer). Duplicate the first tab and delete the existing values in the light-purple background cells. Fill cluster info and common settings appropriately. This tab will be your "working session".

2. As a first run, it is recommended to re-establish a baseline on your cluster. Running all tests on the same cluster allows to eliminate some potential environmental biases. You can probably ignore the table titled "Baseline run (no netobserv)": this is only useful when you want to measure NetObserv overhead versus a cluster without NetObserv.

3. For each run:
  - Run any or all of the hey-ho commands listed for LOW, MEDIUM and HIGH, such as `./hey-ho.sh -r 2 -d 2 -z 10m -n 1 -q 50 -p`. Each command is set up for a 10-minutes run. Note that this may generate a lot of stress on the cluster, especially the HIGH one. It's not impossible that you have to restart a lost node.
  - Gather metrics using the promQL queries provided. For convenience there are some links provided at the top to directly open OpenShift console metrics pages.
  - Write data manually, accordingly. (Note: perhaps at some point we will automate this.. but that's also a good thing to actually take a look at the time-series, you might potentially notice interesting things that you wouldn't with a summary computed automatically).
  - Between runs, restart Loki, Kafka and/or any workload impacted. You should also delete hey-ho pods with `./hey-ho.sh -c -n 3`.

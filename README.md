# hey-ya
Z shell widget to add an LLM-powered assistant to your command-line.

## Prerequisites
This widget uses [`jq`](https://github.com/jqlang/jq). To install, run `brew install jq`.

## Setup
To obtain this Z shell widget, follow these steps:

1. Clone this repository with `git clone https://github.com/the-man-with-no-name/hey-ya.git`.
2. Add the following line to your `~/.zshrc` file: `source <HEY-PATH>/hey.zsh` where `HEY-PATH` is the fully-qualified path to your cloned repository.

## Configuration
`hey` is currently only prepared to integrate with local models obtained through `ollama`. To change the model in use, change the value of `HEY_MODEL` to your preferred value.

## Usage
`hey` is designed to help you run the zsh commands you want by entering plain language and suggesting the appropriate command.

### hey

To determine how many processes are currently running on your machine:

```
me@machine % hey how many processes are running on this machine
```

The result of this command fills the next open command line with:

```
me@machine % ps -e | wc -l
```

This leaves you with the option to choose whether or not to run the command.

### hey -ya

To provide more information about the results of the `hey` command, use the `hey -- -i` pattern.

```
me@machine % hey -- -i
```

This looks back at the last command you ran and the results of this command and provides a summary of the command what the results mean.

To obtain information unrelated to your command history, try

```
me@machine % hey -- -i how does ps work on macOS
```

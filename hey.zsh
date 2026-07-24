# --- Hey: Add LLM reasoning to your ZShell ---

# 1. Configuration
export HEY_MODEL="gemma4:e4b-mlx"
export HEY_API_URL="http://localhost:11434/api/generate"

function _hey_logic() {
    local debug="0"
    local user_prompt="$1"
    local system_prompt="You are a zsh assistant on a Mac computer.
    Return ONLY the shell command to execute. No markdown, no explanations, just the raw code.
    The command should ONLY be a SINGLE LINE.
    Ensure you use a backslash to escape all necessary characters such as:
        newlines,
        spaces in file or directory names,
        single quotes, double quotes, and backslash,
        brackets,
        braces,
        parantheses,
        control characters,
        and escape characters."

    local system_prompt_summary="You are a zsh assistant on a Mac computer.
    Return a summary of what the user is asking in a short, simple sentence.
    DO NOT include the shell comman itself as part of your response, plain english only.
    Start the summary sentence with the verb and do not say YOU or THE USER, keep it simple.
    Ensure you use a backslash to escape all necessary characters such as:
        newlines,
        spaces in file or directory names,
        single quotes, double quotes, and backslash,
        brackets,
        braces,
        parantheses,
        control characters,
        and escape characters."

    # Print thinking message
    print -Pn "\e[3;36mThinking...\e[0m\r"

    # Construct json payload for curl request
    local summary_payload=$(jq -n --arg model "$HEY_MODEL" --arg prompt_s "$user_prompt" --arg system_s "$system_prompt_summary" '{model: $model, prompt: $prompt_s, system: $system_s, stream: false}')
    if [[ $debug == 1 ]]; then
        print -Pn "\e[3;36m(Summary Payload:)\e[0m" "$summary_payload" "\n"
    fi

    local response_summary=$(curl -s "$HEY_API_URL" --data-binary "$summary_payload")
    if [[ $debug == 1 ]]; then
        print -Pn "\e[3;36m(Summary Response:)\e[0m" "$response_summary" "\n"
    fi

    # Construct json payload for curl request
    local payload=$(jq -n --arg model "$HEY_MODEL" --arg prompt "$user_prompt" --arg system "$system_prompt" '{model: $model, prompt: $prompt, system: $system, stream: false}')
    if [[ $debug == 1 ]]; then
        print -Pn "\e[3;36m(Payload:)\e[0m" "$payload" "\n"
    fi

    # 3. Call the API using the file as input
    # We use --data-binary to ensure no character translation happens
    local response=$(curl -s "$HEY_API_URL" --data-binary "$payload")
    if [[ $debug == 1 ]]; then
        print -Pn "\e[3;36m(Response:)\e[0m" "$response" "\n"
    fi

    # Print thinking message
    local clean_text_summary=$(printf '%s\n' "$response_summary" | jq -r ".response")
    print -Pn "\e[3;36m$clean_text_summary\e[0m\e[K\n"

    if [[ $? -ne 0 ]]; then
        print -Pn "\e[31m(Error: Curl failed)\e[0m\n"
        return 1
    fi

    # 4. Parse the response from the file
    local clean_text=$(printf '%s\n' "$response" | jq -r ".response")
    if [[ $debug == 1 ]]; then
        print -Pn "\e[3;36m(Clean Text:)\e[0m" "$clean_text" "\n"
    fi

    if [[ -z "$clean_text" || "$clean_text" == "null" ]]; then
        print -Pn "\e[31m(Error: LLM returned nothing or invalid JSON)\e[0m\n"
    else
        if [[ $debug == 1 ]]; then
            print -Pn "\e[3;36m(BUFFER:)\e[0m\n"
        fi
        local command_text="$clean_text"
        print -z "$command_text"
    fi
}

function _hey_info() {
    setopt local_options
    setopt extended_glob

    local debug="0"

    if [[ $1 =~ ^[[:space:]]*$ ]]; then
        local last_command=$(history | tail -n 1)
        local clean_last_command="${last_command##[0-9 ]#}"
        local last_command_result=$(eval "$clean_last_command")
        if [[ $debug == 1 ]]; then
            print -Pn "\e[3;36mget info about: last command\e[0m\n"
            print -Pn "\e[3;36m$clean_last_command\e[0m\n"
            print -Pn "\e[3;36m$last_command_result\e[0m\n"
        fi

        local system_prompt="You are a zsh knowledge expert on a Mac computer.
        Your only job is to provide information about shell commands and summarize their results.
        You should explain the command and results in plain language and, if you do not know,
        direct the user to man or documentation where they can find information.
        This output is designed to be displayed in a z shell environment, so format the output appropriately.
        Ensure you use a backslash to escape all necessary characters such as:
            newlines,
            spaces in file or directory names,
            single quotes, double quotes, and backslash,
            brackets,
            braces,
            parantheses,
            control characters,
            and escape characters."

        local user_prompt="The last command the user ran is: $last_command
        The result of this last command was: $last_command_result
        Give a brief explanation of what the last command does and what the result says."

        # Construct json payload for curl request
        local payload=$(jq -n --arg model "$HEY_MODEL" --arg prompt "$user_prompt" --arg system "$system_prompt" '{model: $model, prompt: $prompt, system: $system, stream: false}')
        if [[ $debug == 1 ]]; then
            print -Pn "\e[3;36m(Payload:)\e[0m" "$payload" "\n"
        fi

        # 3. Call the API using the file as input
        # We use --data-binary to ensure no character translation happens
        local response=$(curl -s "$HEY_API_URL" --data-binary "$payload")
        if [[ $debug == 1 ]]; then
            print -Pn "\e[3;36m(Response:)\e[0m" "$response" "\n"
        fi

        local clean_text=$(printf '%s\n' "$response" | jq -r ".response")
        print -Pn "\e[3;36m$clean_text\e[0m\e[K\n"
    else
        local system_prompt="You are a zsh knowledge expert on a Mac computer.
        Your only job is to provide information about what the user is asking.
        This output is designed to be displayed in a z shell environment, so format the output appropriately.
        Ensure you use a backslash to escape all necessary characters such as:
            newlines,
            spaces in file or directory names,
            single quotes, double quotes, and backslash,
            brackets,
            braces,
            parantheses,
            control characters,
            and escape characters."

        local user_prompt="$1"

        if [[ $debug == 1 ]]; then
            print -Pn "\e[3;36mget info about: $1\e[0m\n"
        fi

        # Construct json payload for curl request
        local payload=$(jq -n --arg model "$HEY_MODEL" --arg prompt "$user_prompt" --arg system "$system_prompt" '{model: $model, prompt: $prompt, system: $system, stream: false}')
        if [[ $debug == 1 ]]; then
            print -Pn "\e[3;36m(Payload:)\e[0m" "$payload" "\n"
        fi

        # 3. Call the API using the file as input
        # We use --data-binary to ensure no character translation happens
        local response=$(curl -s "$HEY_API_URL" --data-binary "$payload")
        if [[ $debug == 1 ]]; then
            print -Pn "\e[3;36m(Response:)\e[0m" "$response" "\n"
        fi

        local clean_text=$(printf '%s\n' "$response" | jq -r ".response")
        print -Pn "\e[3;36m$clean_text\e[0m\e[K\n"
    fi
}

function _hey_widget() {
    # Strip 'hey ' from the current line buffer
    # print "$@"
    # print $#
    local input="${@#hey }"
    if [[ $debug == 1 ]]; then
        print -Pn "\e[31m( Input: )\e[0m" "$input" "\n"
    fi
    if (( $# >= 2 )); then
        if [[ $2 == "-ya" ]]; then
            local input_stripped="${input#-- }"
            local input_stripped_flag="${input_stripped#-ya}"
            _hey_info "$input_stripped_flag"
        else
            _hey_logic "$input"
        fi
    fi
}

# Register the ZLE widget
zle -N _hey_widget

# Alias for easy access
alias hey='_hey_widget'
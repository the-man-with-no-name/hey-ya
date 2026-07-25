# --- Hey: Add LLM reasoning to your ZShell ---

# @TODO: Use `script [-a -r -q -t] ~/.hey/history.log`
# This prevents us from using eval "$cmd" which is potentially dangerous

# 1. Configuration
export HEY_MODEL="gemma4:e4b-mlx"
export HEY_API_URL="http://localhost:11434/api/generate"

# Usage: _debug "<CATEGORY>" "<TEXT>"
function _debug() {
    local debug="0"
    local debug_color="#56B4E9"
    if [[ $debug == 1 ]]; then
        print -Pn "%F{$debug_color}($1:)%f" "$2" "\n"
    fi
}

# Usage: _think
function _think() {
    # Print thinking message
    print -Pn "%F{$think_color}Thinking...%f\r"
}

function _hey_logic() {
    local user_prompt="$1"

    local system_prompt="You are a zsh assistant on a Mac computer.
    Return ONLY the shell command to execute. No markdown, no explanations, just the raw code.
    The command should ONLY be a single line. DO NOT return a command spanning multiple lines with newline characters.
    This output is displayed in a terminal environment, format the output as such.
    Do not include conversational intro or outro.
    Wrap lines at 80 characters to fit standard terminal windows.
    Strip markdown blocks and markdown headers, do not use triple backticks or markdown fences or headings.
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
    Flag any command that could destroy files or directories as DESTRUCTIVE and WARN the user!
    Flag any command that could take large amounts of time (more than a few seconds) as SLOW and WARN the user!
    This output is displayed in a terminal environment, format the output as such.
    Do not include conversational intro or outro.
    Wrap lines at 80 characters to fit standard terminal windows.
    Strip markdown blocks and markdown headers, do not use triple backticks or markdown fences or headings.
    Ensure you use a backslash to escape all necessary characters such as:
        newlines,
        spaces in file or directory names,
        single quotes, double quotes, and backslash,
        brackets,
        braces,
        parantheses,
        control characters,
        and escape characters."

    local error_color="#D55E00"
    local think_color="#FDF1A9"
    local info_color="#0072B2"
    local debug_color="#56B4E9"

    # Print thinking message
    _think

    # Construct json payload for curl request
    local summary_payload="$(jq -n --arg model "$HEY_MODEL" --arg prompt_s "$user_prompt" --arg system_s "$system_prompt_summary" '{model: $model, prompt: $prompt_s, system: $system_s, stream: false}')"
    _debug "Summary Payload" "$summary_payload"

    local response_summary="$(curl -s "$HEY_API_URL" --data-binary "$summary_payload")"
    _debug "Summary Response" "$response_summary"

    # Construct json payload for curl request
    local payload="$(jq -n --arg model "$HEY_MODEL" --arg prompt "$user_prompt" --arg system "$system_prompt" '{model: $model, prompt: $prompt, system: $system, stream: false}')"
    _debug "Payload" "$payload"

    # 3. Call the API using the file as input
    # We use --data-binary to ensure no character translation happens
    local response="$(curl -s "$HEY_API_URL" --data-binary "$payload")"
    _debug "Response" "$response"

    # Print thinking message
    local clean_text_summary="$(printf '%s\n' "$response_summary" | jq -r ".response")"
    print -Pn "%F{$info_color}$clean_text_summary%f\n"

    if [[ $? -ne 0 ]]; then
        print -Pn "%F{$error_color}(Error: Curl failed)%f\n"
        return 1
    fi

    # 4. Parse the response from the file
    local clean_text="$(printf '%s\n' "$response" | jq -r ".response")"
    _debug "Clean Text" "$clean_text"

    if [[ -z "$clean_text" || "$clean_text" == "null" ]]; then
        print -Pn "%F{$error_color}(Error: LLM returned nothing or invalid JSON)%f\n"
    else
        local command_text="$clean_text"
        print -z "$command_text"
    fi
}

function _hey_info() {
    setopt local_options
    setopt extended_glob

    local error_color="#D55E00"
    local think_color="#FDF1A9"
    local info_color="#0072B2"
    local debug_color="#56B4E9"

    local debug="0"

    if [[ $1 =~ ^[[:space:]]*$ ]]; then
        local last_command=$(history | tail -n 1)
        local clean_last_command="${last_command##[0-9 ]#}"
        local last_command_result=$(eval "$clean_last_command")

        if [[ $debug == 1 ]]; then
            print -Pn "%F{$debug_color}get info about: last command%f\n"
            print -Pn "%F{$debug_color}$clean_last_command%f\n"
            print -Pn "%F{$debug_color}$last_command_result%f\n"
        fi

        # Print thinking message
        print -Pn "%F{$think_color}Thinking...%f\r"

        local system_prompt="You are a zsh knowledge expert on a Mac computer.
        Your only job is to provide information about shell commands and summarize their results.
        Explain the command in plain language and, if you do not know,
        direct the user to man or documentation where they can find information.
        Provide a brief explanation of how the result of the command is interpreted.
        Do not call this result explanation a summary or review.
        This output is displayed in a terminal environment, format the output as such.
        Do not include conversational intro or outro.
        Wrap lines at 80 characters to fit standard terminal windows.
        Strip markdown blocks and markdown headers, do not use triple backticks or markdown fences or headings.
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
            print -Pn "%F{$debug_color}(Payload:)%f" "$payload" "\n"
        fi

        # 3. Call the API using the file as input
        # We use --data-binary to ensure no character translation happens
        local response=$(curl -s "$HEY_API_URL" --data-binary "$payload")
        if [[ $debug == 1 ]]; then
            print -Pn "%F{$debug_color}(Response:)%f" "$response" "\n"
        fi

        local clean_text=$(printf '%s\n' "$response" | jq -r ".response")
        print -Pn "%F{$info_color}$clean_text%f\n"
    else
        local system_prompt="You are a zsh knowledge expert on a Mac computer.
        Your only job is to provide information about what the user is asking.
        This output is displayed in a terminal environment, format the output as such.
        Do not include conversational intro or outro.
        Wrap lines at 80 characters to fit standard terminal windows.
        Strip markdown blocks and markdown headers, do not use triple backticks or markdown fences or headings.
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
        print -Pn "%F{$think_color}Thinking...%f\r"

        local user_prompt="$1"

        if [[ $debug == 1 ]]; then
            print -Pn "%F{$debug_color}get info about: $1%f\n"
        fi

        # Construct json payload for curl request
        local payload=$(jq -n --arg model "$HEY_MODEL" --arg prompt "$user_prompt" --arg system "$system_prompt" '{model: $model, prompt: $prompt, system: $system, stream: false}')
        if [[ $debug == 1 ]]; then
            print -Pn "%F{$debug_color}(Payload:)%f" "$payload" "\n"
        fi

        # 3. Call the API using the file as input
        # We use --data-binary to ensure no character translation happens
        local response=$(curl -s "$HEY_API_URL" --data-binary "$payload")
        if [[ $debug == 1 ]]; then
            print -Pn "%F{$debug_color}(Response:)%f" "$response" "\n"
        fi

        local clean_text=$(printf '%s\n' "$response" | jq -r ".response")
        print -Pn "%F{$info_color}$clean_text%f\n"
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
    if (( $# >= 1 )); then
        if [[ $2 == "-i" ]]; then
            local input_stripped="${input#-- }"
            local input_stripped_flag="${input_stripped#-i}"
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
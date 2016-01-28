# MisraToken

This is a simple project implementing the Jayadev Misra's token-passing Critical Section access control algorithm for the Token Ring topology. It uses docker containers to create the test environment 

## Running

Running this application consists of several steps - it's not really meant to be easy to use, just to work during the laboratory :P However, I might fix it some day.

For now, to run it you have to:

  1. Build the Docker container image:

        # cd docker && bash build_image.sh

  2. Run the startup script:

        # bash startup.sh 4

    (where 4 is the node count)

  3. Copy the command that's shown after "cmd: " without single quotes, paste it and run with ENTER:
        
        cmd: 'MisraToken.coordLoop [0,1,2,3],["172.18.0.2","172.18.0.3","172.18.0.4","172.18.0.5"],["172.18.0.3","172.18.0.4","172.18.0.5","172.18.0.2"],
        [1,2,3,0]'
        Erlang/OTP 18 [erts-7.2.1] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false]

        Compiled lib/misra.ex
        Interactive Elixir (1.2.1) - press Ctrl+C to exit (type h() ENTER for help)

        # iex(coordinator@172.18.0.1)1> MisraToken.coordLoop [0,1,2,3],["172.18.0.2","172.18.0.3","172.18.0.4","172.18.0.5"],["172.18.0.3","172.18.0.4","172.18.0.5","172.18.0.2"], [1,2,3,0]

  4. Enjoy the output


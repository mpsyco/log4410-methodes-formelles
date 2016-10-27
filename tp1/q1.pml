#define NB_CLIENT 1
// Si NB_STATION > NB_CLIENT*3, alors le checker ne termine jamais
#define NB_STATION 4
#define client_id_t int
#define station_id_t int
#define TAILLE_FILE_DATTENTE (NB_CLIENT*3)

// Quel type de message peuvent etre envoyer.
mtype = { DIESEL, ESSENCE, ELEC };

// Le channel "lineup" represente les clients qui attendent pour un guicher
chan lineup = [NB_CLIENT*3] of {client_id_t};

// Il y a un channel par client, afin que le guichet puisse notifier chaque client individuellement.
chan client_chan[NB_CLIENT*3] = [0] of {client_id_t};
chan client_station[NB_CLIENT*3] = [0] of {station_id_t};

// Ce channel sert a passer la commande du client choisi par le guichet, vers le guichet.
chan ticketCounterService = [1] of {mtype};

// 
chan pending_order = [NB_STATION] of {client_id_t, mtype};

proctype client(client_id_t id; mtype engine_type)
{
    printf("Client %d: Je demarre. Mon moteur est de type %e\n", id, engine_type);

    station_id_t station_id;

    do
        ::  printf("Client %d: J'entre dans la station-service\n", id);
            // Entrer dans la station service
            lineup!id;

            // Attendre que le guichet le selectionne
            client_chan[id]?_; // on se fou du contenu du message, ce n'est qu'un rendez-vous.

            // Passer sa commande
            printf("Client %d: Je suis choisi, je commande %e\n", id, engine_type);
            ticketCounterService!engine_type;
            printf("Client %d: Commande passee. En attente d'une station libre.\n", id);

            // Attendre qu une station soit prete
            client_station[id]?station_id; 
            printf("Client %d: Je suis servi du %e par la station %d. Je quitte\n", id, engine_type, station_id);

            // Sort de la station service
            skip;
    od
}

proctype guichet()
{
    printf("Guichet: Je demarre\n");
    client_id_t client_id;
    mtype order;
    do
        // Selectionner un client au hasard dans la file d'attente
        :: lineup??client_id;
        printf("Guichet: Le client %d est choisi\n", client_id);

        // Signaler au client qu'il est choisi
        client_chan[client_id]!client_id; // This is only a rendez-vous, the receiver don't actually care about the value.
        
        // Prendre la commande
        ticketCounterService?order;

        // Transmettre la commande a (aux) station(s)
        pending_order!client_id, order;
    od
}

proctype station(station_id_t id)
{
    printf("Station %d: Je demarre\n", id);
    client_id_t client_id;
    mtype order;
    do
        // Attendre une commande et la recuperer
        ::  pending_order?client_id, order;
            // Accueillir le client et lui delivrer sa commande
            printf("Station %d: J'accueille le client %d et je lui delivre sa commande %e\n", id, client_id, order);
            client_station[client_id]!id;
    od
}

init {
    int i;
    
    run guichet();

    for (i : 1 .. NB_STATION) {
        run station(i);
    }

    atomic {
        for (i : 0 .. NB_CLIENT-1) {
            run client(3*i + 0, DIESEL);
            run client(3*i + 1, ESSENCE);
            run client(3*i + 2, ELEC);
        }
    }
}

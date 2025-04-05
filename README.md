# Cobbleverse Server In Docker Compose
## 

## What Exactly Is This?
### Cobbleverse
Cobbleverse is a modpack (collection of mods) for Java Minecraft that bring an experience much like the main series of Pokemon games to the world of Minecraft

### Docker
Docker is a way of containerizing applications and their dependencies, and does so in a way very akin to virtual machines

### This Particular Solution
This solution will help you set up your own Cobblemon server

## Instructions
### First Run
1) Ensure that you already have Docker/Docker Compose installed
2) Clone the repository
3) Navigate to the folder you cloned this repo to
4) Run the command: `docker-compose up -d` This will instantiate your server (will probably take a minute or two)

#### What will happen when I do this?
1) The system will check to see if the worldname you specified has already been used
2) Assuming it has not, then it will create a new folder for the world
3) If this is a new world, then the mods that make up this modpack will all be downloaded, and saved to the server in the proper spot
4) Next the Minecraft server is started up

### How to Play
The server is using a modpack known as [Cobbleverse](https://modrinth.com/modpack/cobbleverse).
This modpack includes Cobblemon as well as many sidemods to help recreate a Pokemon-like experience.
If your server is running mods, then your Minecraft client (the game itself) also needs to have the same mods.

My recommendation is that you use the [Modrinth App](https://modrinth.com/app).  Once it's installed, you can follow the Cobbleverse link above, and it will prompt you to install it into the Modrinth app.  Proceed to do that.  Once you've done that, then you'll actually be able to launch the proper version of Minecraft (equipped with mods) directly from Modrinth there.  That's the recommended approach.
Once in, simply put in the address of your server.  If you're on the same machine, you can use `localhost` or `127.0.0.1`.
Sometimes you need to specify the port number too.  This server will be utilizing port `25565`.
This means you could use `localhost:25565` or `127.0.0.1:localhost`

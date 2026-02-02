FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 5000
EXPOSE 5001

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["Sfvector.Api/Sfvector.Api.csproj", "Sfvector.Api/"]
RUN dotnet restore "Sfvector.Api/Sfvector.Api.csproj"
COPY . .
WORKDIR "/src/Sfvector.Api"
RUN dotnet build "Sfvector.Api.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "Sfvector.Api.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENV ASPNETCORE_URLS=http://+:5000
ENTRYPOINT ["dotnet", "Sfvector.Api.dll"]

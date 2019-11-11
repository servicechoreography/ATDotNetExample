# Comment out FROM microsoft/dotnet:sdk AS build-env
FROM mcr.microsoft.com/dotnet/core/sdk:2.2-alpine3.9 AS build-env
WORKDIR /app

# Copy csproj and restore as distinct layers
COPY *.csproj ./
RUN dotnet restore

FROM build-env AS scan
WORKDIR /app
ENV PATH="${PATH}:/root/.dotnet/tools"
RUN dotnet tool install --global dotnet-sonarscanner --version 4.6.2
RUN apk update && apk add openjdk8-jre
RUN dotnet sonarscanner begin /k:"atdotnetexample" /n:"atdotnetexample" /v:"1.0.0" \
    /d:sonar.host.url=http://sonarqube.5c5fed11f2ce459c949c.eastus.aksapp.io \
    /d:sonar.cs.opencover.reportsPaths="/**/opencover.xml" \ 
    /d:sonar.coverage.exclusions="*Startup.cs,*Tests*.cs,*testresult*.xml,*opencover*.xml" \ 
    /d:sonar.test.exclusions="*Tests*.cs,*testresult*.xml,*opencover*.xml"
RUN dotnet build atdotnetexample.sln -c debug --no-restore
RUN dotnet test atdotnetexample.sln -c debug --no-restore --logger trx /p:CollectCoverage=true \
    -p:Exclude="[xunit*]*" /p:CoverletOutputFormat=opencover /p:CoverletOutput="TestResults/opencover.xml"

RUN dotnet sonarscanner end

# Copy everything else and build
COPY . ./
RUN dotnet publish -c Release -o out

# Build runtime image
FROM microsoft/dotnet:aspnetcore-runtime
WORKDIR /app
COPY --from=build-env /app/out .
ENTRYPOINT ["dotnet", "dotnet-example.dll"]

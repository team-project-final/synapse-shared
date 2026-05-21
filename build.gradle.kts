import java.net.HttpURLConnection
import java.net.URI
import java.nio.charset.StandardCharsets
import java.util.Base64

plugins {
    java
    id("com.github.davidmc24.gradle.plugin.avro") version "1.9.1"
    `maven-publish`
}

group = "com.synapse"
version = "0.1.0"

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(21))
    }
}

repositories {
    mavenCentral()
    maven { url = uri("https://packages.confluent.io/maven/") }
}

dependencies {
    implementation("org.apache.avro:avro:1.11.3")
    implementation("io.confluent:kafka-avro-serializer:7.5.0")
}

val schemaRegistryUrl = providers.environmentVariable("SCHEMA_REGISTRY_URL")
val schemaRegistryUser = providers.environmentVariable("SCHEMA_REGISTRY_USER")
val schemaRegistryPassword = providers.environmentVariable("SCHEMA_REGISTRY_PASSWORD")

fun HttpURLConnection.applyBasicAuth(user: String?, password: String?) {
    if (!user.isNullOrBlank() && !password.isNullOrBlank()) {
        val credentials = "$user:$password"
        val token = Base64.getEncoder().encodeToString(credentials.toByteArray(StandardCharsets.UTF_8))
        setRequestProperty("Authorization", "Basic $token")
    }
}

fun schemaPayload(schema: String): String {
    val escaped = schema
        .replace("\\", "\\\\")
        .replace("\"", "\\\"")
        .replace("\r", "")
        .replace("\n", "")
    return "{\"schema\":\"$escaped\"}"
}

fun readResponse(connection: HttpURLConnection): String {
    val stream = if (connection.responseCode in 200..299) {
        connection.inputStream
    } else {
        connection.errorStream
    }

    return stream?.bufferedReader(StandardCharsets.UTF_8)?.use { it.readText() }.orEmpty()
}

fun openSchemaRegistryConnection(
    endpoint: String,
    method: String,
    user: String?,
    password: String?,
): HttpURLConnection {
    val connection = URI(endpoint).toURL().openConnection() as HttpURLConnection
    connection.requestMethod = method
    connection.setRequestProperty("Content-Type", "application/vnd.schemaregistry.v1+json")
    connection.applyBasicAuth(user, password)
    return connection
}

fun requireSuccess(connection: HttpURLConnection, action: String): String {
    val responseBody = readResponse(connection)
    if (connection.responseCode !in 200..299) {
        error("$action failed with HTTP ${connection.responseCode}: $responseBody")
    }
    return responseBody
}

fun verifyCompatibility(
    registryUrl: String,
    subject: String,
    schemaFile: File,
    expectedCompatible: Boolean,
    user: String?,
    password: String?,
) {
    val connection = openSchemaRegistryConnection(
        "$registryUrl/compatibility/subjects/$subject/versions/latest",
        "POST",
        user,
        password,
    )
    connection.doOutput = true
    connection.outputStream.use { output ->
        output.write(schemaPayload(schemaFile.readText(Charsets.UTF_8)).toByteArray(StandardCharsets.UTF_8))
    }

    val responseBody = requireSuccess(
        connection,
        "Schema compatibility check for ${schemaFile.name}",
    )
    val compatibilityResult = Regex("\"is_compatible\"\\s*:\\s*(true|false)")
        .find(responseBody)
        ?.groupValues
        ?.get(1)
        ?.toBooleanStrictOrNull()
        ?: error("Unable to parse compatibility response: $responseBody")

    if (compatibilityResult != expectedCompatible) {
        error(
            "Expected compatibility=$expectedCompatible for ${schemaFile.name}, but got $compatibilityResult: $responseBody",
        )
    }
}

tasks.register("testSchemasTask") {
    group = "verification"
    description = "Checks the knowledge note schema against Schema Registry when registry settings are available."

    dependsOn("generateAvroJava")
    inputs.files(fileTree("src/main/avro") { include("**/*.avsc") })
    inputs.files(fileTree("src/test/resources/schema-samples") { include("**/*.avsc") })

    doLast {
        val registryUrl = schemaRegistryUrl.orNull
        if (registryUrl.isNullOrBlank()) {
            logger.lifecycle("SCHEMA_REGISTRY_URL is not set. Skipping remote compatibility checks.")
            return@doLast
        }

        val subject = "knowledge.note.note-created-v1-value"
        val user = schemaRegistryUser.orNull
        val password = schemaRegistryPassword.orNull
        val baseSchemaFile = file("src/main/avro/knowledge/NoteCreated.avsc")
        val compatibleSchemaFile = file("src/test/resources/schema-samples/note-created-v2-compatible.avsc")
        val incompatibleSchemaFile = file("src/test/resources/schema-samples/note-created-v2-incompatible.avsc")

        val latestVersionConnection = openSchemaRegistryConnection(
            "$registryUrl/subjects/$subject/versions/latest",
            "GET",
            user,
            password,
        )
        val latestVersionStatus = latestVersionConnection.responseCode
        val latestVersionResponse = readResponse(latestVersionConnection)

        if (latestVersionStatus == 404) {
            logger.warn(
                "Schema subject {} does not exist in the configured registry yet. Parsed schemas locally and skipped remote compatibility checks.",
                subject,
            )
            return@doLast
        }

        if (latestVersionStatus !in 200..299) {
            error("Fetch latest schema version for $subject failed with HTTP $latestVersionStatus: $latestVersionResponse")
        }
        logger.lifecycle("Latest schema version for {} is available: {}", subject, latestVersionResponse)

        verifyCompatibility(registryUrl, subject, baseSchemaFile, true, user, password)
        verifyCompatibility(registryUrl, subject, compatibleSchemaFile, true, user, password)
        verifyCompatibility(registryUrl, subject, incompatibleSchemaFile, false, user, password)
    }
}

publishing {
    publications {
        create<MavenPublication>("maven") {
            from(components["java"])
        }
    }
}

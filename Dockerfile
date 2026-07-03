FROM eclipse-temurin:17-jdk 

RUN groupadd -r petclinic && useradd -r -g petclinic petclinic

WORKDIR /app
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN chmod +x mvnw
RUN ./mvnw dependency:go-offline -q
COPY src/ src/
RUN ./mvnw package -DskipTests -q && \
    cp target/spring-petclinic-*.jar app.jar && \
    rm -rf target ~/.m2/repository
RUN chown -R petclinic:petclinic /app
USER petclinic
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]

docker-build-push:
    name: Build and Push to ECR
    runs-on: ubuntu-latest
    needs: publish
    if: |
      github.ref == 'refs/heads/dev' &&
      github.event_name == 'push'
    permissions:
      id-token: write
      contents: read
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
 
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ env.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}
 
      - name: Login to ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2
 
      - name: Build, tag, and push image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build \
            -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker push \
            $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker tag \
            $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG \
            $ECR_REGISTRY/$ECR_REPOSITORY:latest
          docker push \
            $ECR_REGISTRY/$ECR_REPOSITORY:latest
